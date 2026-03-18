//
//  BookmarksView.swift
//  PDFReader
//
//  Sidebar view for managing bookmarks - Liquid Glass Design
//

import SwiftUI

struct BookmarksView: View {
    @EnvironmentObject var documentManager: DocumentManager
    @EnvironmentObject var bookmarkManager: BookmarkManager
    @State private var editingBookmark: Bookmark?
    @State private var showingEditSheet = false
    @State private var hoveredBookmarkID: UUID?
    
    var currentBookmarks: [Bookmark] {
        bookmarkManager.bookmarks(for: documentManager.fileName)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with glass effect
            HStack {
                Text("Bookmarks")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("\(currentBookmarks.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.accentColor))
                
                Button(action: addBookmarkForCurrentPage) {
                    Image(systemName: isCurrentPageBookmarked ? "bookmark.fill" : "plus")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isCurrentPageBookmarked ? .yellow : .accentColor)
                }
                .buttonStyle(.plain)
                .disabled(documentManager.pdfDocument == nil)
                .help(isCurrentPageBookmarked ? "Current page bookmarked" : "Add bookmark for current page")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            
            Divider()
            
            if currentBookmarks.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(currentBookmarks) { bookmark in
                            BookmarkCardView(
                                bookmark: bookmark,
                                isActive: bookmark.pageIndex == documentManager.currentPageIndex,
                                isHovered: hoveredBookmarkID == bookmark.id,
                                onTap: { documentManager.goToPage(bookmark.pageIndex) },
                                onEdit: {
                                    editingBookmark = bookmark
                                    showingEditSheet = true
                                },
                                onDelete: {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        bookmarkManager.removeBookmark(for: documentManager.fileName, bookmark: bookmark)
                                    }
                                }
                            )
                            .onHover { hovering in
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    hoveredBookmarkID = hovering ? bookmark.id : nil
                                }
                            }
                        }
                    }
                    .padding(10)
                }
            }
        }
        .background(.ultraThinMaterial)
        .sheet(isPresented: $showingEditSheet) {
            if let bookmark = editingBookmark {
                BookmarkEditView(bookmark: bookmark) { updatedBookmark in
                    bookmarkManager.updateBookmark(for: documentManager.fileName, bookmark: updatedBookmark)
                }
            }
        }
    }
    
    private var isCurrentPageBookmarked: Bool {
        currentBookmarks.contains { $0.pageIndex == documentManager.currentPageIndex }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 70, height: 70)
                
                Image(systemName: "bookmark")
                    .font(.system(size: 28))
                    .foregroundColor(.accentColor.opacity(0.7))
            }
            
            VStack(spacing: 6) {
                Text("No Bookmarks")
                    .font(.system(size: 14, weight: .semibold))
                
                Text("Press ⌘D to add a bookmark\nfor the current page")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private func addBookmarkForCurrentPage() {
        bookmarkManager.addBookmark(for: documentManager.fileName, pageIndex: documentManager.currentPageIndex)
    }
}

// MARK: - Bookmark Card View (Liquid Glass)
struct BookmarkCardView: View {
    let bookmark: Bookmark
    let isActive: Bool
    let isHovered: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            // Color indicator with glow when active
            ZStack {
                if isActive {
                    Circle()
                        .fill(bookmarkColor.opacity(0.3))
                        .frame(width: 20, height: 20)
                        .blur(radius: 4)
                }
                
                Circle()
                    .fill(bookmarkColor)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.5), lineWidth: isActive ? 2 : 0)
                    )
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(bookmark.title)
                    .font(.system(size: 12, weight: isActive ? .semibold : .medium))
                    .foregroundColor(isActive ? .accentColor : .primary)
                    .lineLimit(1)
                
                if !bookmark.note.isEmpty {
                    Text(bookmark.note)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Page number or action buttons
            if isHovered {
                HStack(spacing: 4) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                            .foregroundColor(.accentColor)
                            .frame(width: 22, height: 22)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                            .frame(width: 22, height: 22)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("p.\(bookmark.pageIndex + 1)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isActive ? Color.accentColor.opacity(0.15) : (isHovered ? Color.primary.opacity(0.08) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isActive ? Color.accentColor.opacity(0.4) : (isHovered ? Color.primary.opacity(0.15) : Color.clear),
                    lineWidth: isActive ? 1.5 : 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .contextMenu {
            Button("Go to Page", action: onTap)
            Button("Edit", action: onEdit)
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
    
    private var bookmarkColor: Color {
        switch bookmark.color {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        }
    }
}

struct BookmarkEditView: View {
    @Environment(\.dismiss) var dismiss
    @State var bookmark: Bookmark
    var onSave: (Bookmark) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Bookmark")
                .font(.headline)
            
            TextField("Title", text: $bookmark.title)
                .textFieldStyle(.roundedBorder)
            
            TextField("Note", text: $bookmark.note)
                .textFieldStyle(.roundedBorder)
            
            Picker("Color", selection: $bookmark.color) {
                ForEach(BookmarkColor.allCases, id: \.self) { color in
                    HStack {
                        Circle()
                            .fill(colorFor(color))
                            .frame(width: 12, height: 12)
                        Text(color.rawValue.capitalized)
                    }
                    .tag(color)
                }
            }
            .pickerStyle(.menu)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Save") {
                    onSave(bookmark)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 300)
    }
    
    private func colorFor(_ bookmarkColor: BookmarkColor) -> Color {
        switch bookmarkColor {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        }
    }
}
