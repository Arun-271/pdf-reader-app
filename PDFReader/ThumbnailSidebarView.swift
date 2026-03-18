//
//  ThumbnailSidebarView.swift
//  PDFReader
//
//  Sidebar showing PDF page thumbnails or Table of Contents with caching
//

import SwiftUI
import PDFKit

// MARK: - View Mode
enum SidebarViewMode: String, CaseIterable {
    case thumbnails = "Pages"
    case tableOfContents = "Contents"
    
    var icon: String {
        switch self {
        case .thumbnails: return "square.grid.2x2"
        case .tableOfContents: return "list.bullet.indent"
        }
    }
}

// MARK: - Thumbnail Cache
final class ThumbnailCache {
    static let shared = ThumbnailCache()
    
    private var cache = NSCache<NSString, NSImage>()
    private let queue = DispatchQueue(label: "com.pdfreader.thumbnailCache", qos: .userInitiated, attributes: .concurrent)
    
    init() {
        cache.countLimit = 100  // Max 100 thumbnails in memory
        cache.totalCostLimit = 50 * 1024 * 1024  // 50MB limit
    }
    
    func thumbnail(for key: String) -> NSImage? {
        cache.object(forKey: key as NSString)
    }
    
    func setThumbnail(_ image: NSImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
    
    func clear() {
        cache.removeAllObjects()
    }
    
    func cacheKey(documentName: String, pageIndex: Int) -> String {
        "\(documentName)_page_\(pageIndex)"
    }
}

// MARK: - TOC Item
struct TOCItem: Identifiable {
    let id = UUID()
    let title: String
    let pageIndex: Int
    let level: Int
    var children: [TOCItem]
}

struct ThumbnailSidebarView: View {
    @EnvironmentObject var documentManager: DocumentManager
    @EnvironmentObject var bookmarkManager: BookmarkManager
    @State private var viewMode: SidebarViewMode = .thumbnails
    @State private var tocItems: [TOCItem] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Mode toggle with liquid glass effect
            HStack(spacing: 2) {
                ForEach(SidebarViewMode.allCases, id: \.self) { mode in
                    ModeToggleButton(
                        mode: mode,
                        isSelected: viewMode == mode
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewMode = mode
                        }
                    }
                }
            }
            .padding(4)
            .background(Color.primary.opacity(0.08))
            .cornerRadius(10)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            
            Divider()
            
            // Content
            if let document = documentManager.pdfDocument {
                Group {
                    switch viewMode {
                    case .thumbnails:
                        thumbnailsList(document: document)
                    case .tableOfContents:
                        tableOfContentsList(document: document)
                    }
                }
            } else {
                Spacer()
                Text("No document")
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .background(.ultraThinMaterial)
        .onAppear {
            loadTOC()
        }
        .onChange(of: documentManager.pdfDocument) { _ in
            loadTOC()
        }
    }
    
    // MARK: - Thumbnails List
    private func thumbnailsList(document: PDFDocument) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(0..<document.pageCount, id: \.self) { index in
                        ThumbnailItemView(
                            document: document,
                            pageIndex: index,
                            isSelected: index == documentManager.currentPageIndex,
                            isBookmarked: isPageBookmarked(index),
                            documentName: documentManager.fileName
                        )
                        .id(index)
                        .onTapGesture {
                            documentManager.goToPage(index)
                        }
                    }
                }
                .padding(8)
            }
            .onChange(of: documentManager.currentPageIndex) { newIndex in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }
    
    // MARK: - Table of Contents
    private func tableOfContentsList(document: PDFDocument) -> some View {
        Group {
            if tocItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No Table of Contents")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("This PDF doesn't have\na table of contents")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                    Spacer()
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(tocItems) { item in
                                TOCItemView(
                                    item: item,
                                    currentPageIndex: documentManager.currentPageIndex
                                ) { pageIndex in
                                    documentManager.goToPage(pageIndex)
                                }
                            }
                        }
                        .padding(8)
                    }
                    .onChange(of: documentManager.currentPageIndex) { newIndex in
                        // Find closest TOC item and scroll to it
                        if let closest = findClosestTOCItem(for: newIndex) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(closest.id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    private func isPageBookmarked(_ pageIndex: Int) -> Bool {
        bookmarkManager.bookmarks(for: documentManager.fileName).contains { $0.pageIndex == pageIndex }
    }
    
    private func loadTOC() {
        guard let document = documentManager.pdfDocument,
              let outline = document.outlineRoot else {
            tocItems = []
            return
        }
        
        tocItems = parseTOC(outline: outline, level: 0)
    }
    
    private func parseTOC(outline: PDFOutline, level: Int) -> [TOCItem] {
        var items: [TOCItem] = []
        
        for i in 0..<outline.numberOfChildren {
            guard let child = outline.child(at: i) else { continue }
            
            let title = child.label ?? "Untitled"
            var pageIndex = 0
            
            if let destination = child.destination,
               let page = destination.page,
               let doc = page.document {
                pageIndex = doc.index(for: page)
            }
            
            let children = parseTOC(outline: child, level: level + 1)
            items.append(TOCItem(title: title, pageIndex: pageIndex, level: level, children: children))
        }
        
        return items
    }
    
    private func findClosestTOCItem(for pageIndex: Int) -> TOCItem? {
        var closest: TOCItem?
        var closestDistance = Int.max
        
        func search(in items: [TOCItem]) {
            for item in items {
                if item.pageIndex <= pageIndex {
                    let distance = pageIndex - item.pageIndex
                    if distance < closestDistance {
                        closestDistance = distance
                        closest = item
                    }
                }
                search(in: item.children)
            }
        }
        
        search(in: tocItems)
        return closest
    }
}

// MARK: - Mode Toggle Button
struct ModeToggleButton: View {
    let mode: SidebarViewMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: mode.icon)
                    .font(.system(size: 11, weight: .medium))
                Text(mode.rawValue)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .foregroundColor(isSelected ? .white : .secondary)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - TOC Item View
struct TOCItemView: View {
    let item: TOCItem
    let currentPageIndex: Int
    let onTap: (Int) -> Void
    @State private var isExpanded = true
    @State private var isHovered = false
    
    private var isActive: Bool {
        if item.children.isEmpty {
            return item.pageIndex == currentPageIndex
        }
        // Check if current page is within this section
        let nextSectionStart = item.children.first?.pageIndex ?? Int.max
        return currentPageIndex >= item.pageIndex && currentPageIndex < nextSectionStart
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Item row
            HStack(spacing: 6) {
                // Expand/collapse button for items with children
                if !item.children.isEmpty {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 12)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer().frame(width: 12)
                }
                
                Text(item.title)
                    .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? .accentColor : .primary)
                    .lineLimit(2)
                
                Spacer()
                
                Text("\(item.pageIndex + 1)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.leading, CGFloat(item.level * 12))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? Color.accentColor.opacity(0.12) : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
            )
            .contentShape(Rectangle())
            .onTapGesture {
                onTap(item.pageIndex)
            }
            .onHover { hovering in
                isHovered = hovering
            }
            .id(item.id)
            
            // Children
            if isExpanded && !item.children.isEmpty {
                ForEach(item.children) { child in
                    TOCItemView(
                        item: child,
                        currentPageIndex: currentPageIndex,
                        onTap: onTap
                    )
                }
            }
        }
    }
}

struct ThumbnailItemView: View {
    let document: PDFDocument
    let pageIndex: Int
    let isSelected: Bool
    let isBookmarked: Bool
    let documentName: String
    
    @State private var thumbnail: NSImage?
    
    private var cacheKey: String {
        ThumbnailCache.shared.cacheKey(documentName: documentName, pageIndex: pageIndex)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                // Thumbnail
                if let thumbnail = thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 140, maxHeight: 180)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 100, height: 130)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.7)
                        )
                }
                
                // Bookmark indicator
                if isBookmarked {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.yellow)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        .padding(4)
                }
            }
            .padding(4)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            
            Text("\(pageIndex + 1)")
                .font(.caption)
                .foregroundColor(isSelected ? .accentColor : .secondary)
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        // Check cache first
        if let cachedThumbnail = ThumbnailCache.shared.thumbnail(for: cacheKey) {
            self.thumbnail = cachedThumbnail
            return
        }
        
        // Generate thumbnail in background
        DispatchQueue.global(qos: .userInitiated).async {
            guard let page = document.page(at: pageIndex) else { return }
            
            let pageRect = page.bounds(for: .mediaBox)
            let scale: CGFloat = 140 / max(pageRect.width, pageRect.height)
            let thumbnailSize = CGSize(
                width: pageRect.width * scale,
                height: pageRect.height * scale
            )
            
            let image = page.thumbnail(of: thumbnailSize, for: .mediaBox)
            
            // Cache the thumbnail
            ThumbnailCache.shared.setThumbnail(image, for: cacheKey)
            
            DispatchQueue.main.async {
                self.thumbnail = image
            }
        }
    }
}

struct ThumbnailSidebarView_Previews: PreviewProvider {
    static var previews: some View {
        ThumbnailSidebarView()
            .environmentObject(DocumentManager())
            .environmentObject(BookmarkManager())
            .frame(width: 200, height: 400)
    }
}
