//
//  ContentView.swift
//  PDFReader
//
//  Main content view with PDF viewer and sidebar
//

import SwiftUI
import PDFKit

struct ContentView: View {
    @EnvironmentObject var documentManager: DocumentManager
    @EnvironmentObject var bookmarkManager: BookmarkManager
    @EnvironmentObject var recentDocumentsManager: RecentDocumentsManager
    @EnvironmentObject var aiManager: AIAssistantManager
    
    @State private var showRecentDocuments = false
    
    var body: some View {
        ZStack {
            // Normal mode layout
            if !documentManager.showFocusMode {
                VStack(spacing: 0) {
                    // Toolbar
                    ToolbarView()
                    
                    // Search bar (conditional)
                    if documentManager.showSearch {
                        SearchBarView()
                    }
                    
                    // Main content with sidebars
                    HSplitView {
                        // Left Sidebar
                        if documentManager.showSidebar {
                            LeftSidebarView()
                        }
                        
                        // PDF View with bookmark overlay
                        ZStack(alignment: .topTrailing) {
                            if documentManager.pdfDocument != nil {
                                PDFKitView()
                                    .environmentObject(documentManager)
                            } else {
                                WelcomeView()
                            }
                            
                            // Bookmark indicator overlay
                            if documentManager.pdfDocument != nil {
                                BookmarkPageIndicator()
                            }
                        }
                        .frame(minWidth: 400)
                        
                        // Right Panel
                        if documentManager.showRightPanel {
                            LiquidGlassPanel()
                        }
                    }
                }
            } else {
                // Focus Mode - Full screen PDF only
                InlineFocusModeView()
                    .environmentObject(documentManager)
            }
        }
        .onDrop(of: [.pdf, .fileURL], isTargeted: nil) { providers in
            documentManager.handleDrop(providers: providers)
        }
        .onChange(of: documentManager.fileURL) { url in
            // Add to recent documents when a file is opened
            if let url = url {
                recentDocumentsManager.addDocument(
                    url: url,
                    pageCount: documentManager.pageCount,
                    currentPage: documentManager.currentPageIndex
                )
            }
        }
        .onChange(of: documentManager.currentPageIndex) { pageIndex in
            // Update recent document with current page
            if let url = documentManager.fileURL {
                recentDocumentsManager.updateLastPage(for: url, pageIndex: pageIndex)
            }
        }
        .sheet(isPresented: $showRecentDocuments) {
            RecentDocumentsView()
        }
        .alert("Save Changes?", isPresented: $documentManager.showSavePrompt) {
            Button("Save") {
                documentManager.saveDocument()
                documentManager.closeDocument()
            }
            Button("Discard", role: .destructive) {
                documentManager.closeDocument()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You have unsaved changes in \"\(documentManager.fileName)\". Do you want to save them before closing?")
        }
    }
}

// MARK: - Bookmark Page Indicator
struct BookmarkPageIndicator: View {
    @EnvironmentObject var documentManager: DocumentManager
    @EnvironmentObject var bookmarkManager: BookmarkManager
    @State private var showIndicator = false
    
    private var currentBookmark: Bookmark? {
        bookmarkManager.bookmarks(for: documentManager.fileName)
            .first { $0.pageIndex == documentManager.currentPageIndex }
    }
    
    var body: some View {
        Group {
            if let bookmark = currentBookmark {
                HStack(spacing: 6) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(bookmarkColor(bookmark.color))
                    
                    if showIndicator {
                        Text(bookmark.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, showIndicator ? 12 : 8)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                )
                .padding(16)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showIndicator = true
                    }
                    // Auto-hide after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation(.easeIn(duration: 0.2)) {
                            showIndicator = false
                        }
                    }
                }
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showIndicator = hovering
                    }
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: currentBookmark?.id)
    }
    
    private func bookmarkColor(_ color: BookmarkColor) -> Color {
        switch color {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        }
    }
}

// MARK: - Left Sidebar with Icon Tabs
struct LeftSidebarView: View {
    @EnvironmentObject var documentManager: DocumentManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Icon-based tab bar for responsiveness
            HStack(spacing: 0) {
                SidebarTabButton(
                    icon: "square.grid.2x2",
                    title: "Pages",
                    isSelected: documentManager.sidebarMode == .thumbnails
                ) {
                    documentManager.sidebarMode = .thumbnails
                }
                
                SidebarTabButton(
                    icon: "bookmark",
                    title: "Bookmarks",
                    isSelected: documentManager.sidebarMode == .bookmarks
                ) {
                    documentManager.sidebarMode = .bookmarks
                }
                
                SidebarTabButton(
                    icon: "pencil.tip",
                    title: "Annotations",
                    isSelected: documentManager.sidebarMode == .annotations
                ) {
                    documentManager.sidebarMode = .annotations
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()

            // Sidebar content
            if documentManager.pdfDocument != nil {
                switch documentManager.sidebarMode {
                case .thumbnails:
                    ThumbnailSidebarView()
                case .bookmarks:
                    BookmarksView()
                case .annotations:
                    AnnotationsView()
                }
            } else {
                Spacer()
            }
        }
        .frame(minWidth: 160, idealWidth: 200, maxWidth: 280)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Sidebar Tab Button
struct SidebarTabButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    private var displayIcon: String {
        let fillable = ["square.grid.2x2", "bookmark"]
        if isSelected && fillable.contains(icon) {
            return icon + ".fill"
        }
        return icon
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.2)
        } else if isHovered {
            return Color.primary.opacity(0.1)
        }
        return Color.clear
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: displayIcon)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .frame(height: 20)
                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .medium : .regular))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundColor(isSelected ? .accentColor : (isHovered ? .primary : .secondary))
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Liquid Glass Right Panel
struct LiquidGlassPanel: View {
    @EnvironmentObject var documentManager: DocumentManager
    
    // Essential modes for the panel
    private let essentialModes: [RightPanelMode] = [.ai, .dictionary, .webSearch, .citations, .timer]
    private let moreMenuModes: [RightPanelMode] = [.ocr, .progress, .cloud, .googleDrive]
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Mode selector with icons - responsive with overflow menu
                HStack(spacing: 8) {
                    ForEach(essentialModes, id: \.self) { mode in
                        GlassPanelButton(
                            mode: mode,
                            isSelected: documentManager.rightPanelMode == mode,
                            isCompact: geometry.size.width < 320
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                documentManager.rightPanelMode = mode
                            }
                        }
                    }
                    
                    // More menu for additional modes
                    Menu {
                        ForEach(moreMenuModes, id: \.self) { mode in
                            Button(action: {
                                withAnimation(.spring(response: 0.3)) {
                                    documentManager.rightPanelMode = mode
                                }
                            }) {
                                Label(mode.rawValue, systemImage: iconForMode(mode))
                            }
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: moreMenuModes.contains(documentManager.rightPanelMode) ? iconForMode(documentManager.rightPanelMode) : "ellipsis")
                                .font(.system(size: geometry.size.width < 320 ? 16 : 18, weight: moreMenuModes.contains(documentManager.rightPanelMode) ? .semibold : .regular))
                            
                            if geometry.size.width >= 320 {
                                Text(moreMenuModes.contains(documentManager.rightPanelMode) ? titleForMode(documentManager.rightPanelMode) : "More")
                                    .font(.caption2)
                                    .fontWeight(moreMenuModes.contains(documentManager.rightPanelMode) ? .semibold : .medium)
                            }
                        }
                        .foregroundColor(moreMenuModes.contains(documentManager.rightPanelMode) ? .accentColor : .secondary)
                        .frame(maxWidth: .infinity, minHeight: geometry.size.width < 320 ? 40 : 50)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(moreMenuModes.contains(documentManager.rightPanelMode) ? Color.accentColor.opacity(0.2) : Color.clear)
                        )
                    }
                    .menuStyle(.borderlessButton)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                
                // Content area
                ZStack {
                    switch documentManager.rightPanelMode {
                    case .ai:
                        AIAssistantView()
                    case .dictionary:
                        DictionaryView()
                    case .webSearch:
                        WebSearchView()
                    case .citations:
                        CitationExtractorView()
                    case .ocr:
                        OCRView()
                    case .timer:
                        FocusTimerView()
                    case .progress:
                        ReadingProgressView()
                    case .googleDrive:
                        VStack(spacing: 16) {
                            Image(systemName: "externaldrive.badge.icloud")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            Text("Cloud Drives")
                                .font(.title3.bold())
                            
                            Text("Access PDFs directly from Google Drive, iCloud, or Dropbox using the native file picker.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button(action: { documentManager.openDocument() }) {
                                Label("Open from Cloud", systemImage: "folder")
                                    .frame(maxWidth: 160)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .padding(.top, 8)
                            
                            if documentManager.pdfDocument != nil {
                                Button(action: { documentManager.saveDocumentAs() }) {
                                    Label("Export to Cloud", systemImage: "square.and.arrow.up")
                                        .frame(maxWidth: 160)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(.ultraThinMaterial)
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.15), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 1),
                alignment: .top
            )
        }
        .frame(minWidth: 280, idealWidth: 350, maxWidth: 500)
    }
    
    private func iconForMode(_ mode: RightPanelMode) -> String {
        switch mode {
        case .ai: return "sparkles"
        case .dictionary: return "text.book.closed"
        case .webSearch: return "globe"
        case .citations: return "quote.bubble"
        case .ocr: return "doc.text.viewfinder"
        case .timer: return "timer"
        case .progress: return "chart.bar"
        case .cloud: return "icloud"
        case .googleDrive: return "externaldrive"
        }
    }
    
    private func titleForMode(_ mode: RightPanelMode) -> String {
        switch mode {
        case .ai: return "AI"
        case .dictionary: return "Dict"
        case .webSearch: return "Web"
        case .citations: return "Cite"
        case .ocr: return "OCR"
        case .timer: return "Timer"
        case .progress: return "Stats"
        case .cloud: return "Cloud"
        case .googleDrive: return "Drive"
        }
    }
}

// MARK: - Glass Panel Button
struct GlassPanelButton: View {
    let mode: RightPanelMode
    let isSelected: Bool
    let isCompact: Bool
    let action: () -> Void
    @State private var isHovered = false

    var icon: String {
        switch mode {
        case .ai: return "sparkles"
        case .dictionary: return "text.book.closed"
        case .webSearch: return "globe"
        case .citations: return "quote.bubble"
        case .ocr: return "doc.text.viewfinder"
        case .timer: return "timer"
        case .progress: return "chart.bar"
        case .cloud: return "icloud"
        case .googleDrive: return "externaldrive"
        }
    }

    var title: String {
        switch mode {
        case .ai: return "AI"
        case .dictionary: return "Dict"
        case .webSearch: return "Web"
        case .citations: return "Cite"
        case .ocr: return "OCR"
        case .timer: return "Timer"
        case .progress: return "Stats"
        case .cloud: return "Cloud"
        case .googleDrive: return "Drive"
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.2)
        } else if isHovered {
            return Color.primary.opacity(0.1)
        }
        return Color.clear
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: isCompact ? 16 : 18, weight: isSelected ? .semibold : .regular))
                    .symbolRenderingMode(.hierarchical)

                if !isCompact {
                    Text(title)
                        .font(.system(size: 9, weight: isSelected ? .semibold : .medium))
                }
            }
            .foregroundColor(isSelected ? .accentColor : (isHovered ? .primary : .secondary))
            .frame(maxWidth: .infinity, minHeight: isCompact ? 40 : 50)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor.opacity(0.4) : (isHovered ? Color.primary.opacity(0.2) : Color.clear), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Welcome View (No Document)
struct WelcomeView: View {
    @EnvironmentObject var documentManager: DocumentManager
    @EnvironmentObject var recentDocumentsManager: RecentDocumentsManager
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Open a PDF file to get started")
                .font(.title3)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Button(action: { documentManager.openDocument() }) {
                    Label("Open PDF", systemImage: "folder")
                        .frame(width: 150)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Text("or drag and drop a PDF file here")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 10)
            
            // Recent documents
            if !recentDocumentsManager.recentDocuments.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Documents")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    ForEach(recentDocumentsManager.recentDocuments.prefix(5)) { doc in
                        Button(action: {
                            openRecentDocument(doc)
                        }) {
                            HStack {
                                Image(systemName: "doc.fill")
                                    .foregroundColor(.red)
                                Text(doc.fileName)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(12)
                .frame(maxWidth: 300)
            }
            
            // Keyboard shortcuts help
            VStack(alignment: .leading, spacing: 8) {
                Text("Keyboard Shortcuts")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                ShortcutRow(keys: "⌘ O", description: "Open file")
                ShortcutRow(keys: "⌘ H", description: "Toggle highlighter")
                ShortcutRow(keys: "⌘ F", description: "Find in document")
                ShortcutRow(keys: "⌘ D", description: "Add bookmark")
                ShortcutRow(keys: "⌥ ⌘ S", description: "Toggle sidebar")
                ShortcutRow(keys: "⌥ ⌘ R", description: "Toggle right panel")
            }
            .padding()
            .background(.regularMaterial)
            .cornerRadius(12)
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func openRecentDocument(_ doc: RecentDocument) {
        // Try to load directly from URL path
        let url = doc.url
        
        if FileManager.default.fileExists(atPath: url.path) {
            documentManager.loadDocument(from: url)
            if doc.lastPageIndex > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    documentManager.goToPage(doc.lastPageIndex)
                }
            }
        } else {
            // Try security-scoped access as fallback
            if doc.startAccess(), let resolvedURL = doc.resolvedURL() {
                if FileManager.default.fileExists(atPath: resolvedURL.path) {
                    documentManager.loadDocument(from: resolvedURL)
                    if doc.lastPageIndex > 0 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            documentManager.goToPage(doc.lastPageIndex)
                        }
                    }
                }
            }
        }
    }
}

struct ShortcutRow: View {
    let keys: String
    let description: String
    
    var body: some View {
        HStack {
            Text(keys)
                .font(.system(.body, design: .monospaced))
                .frame(width: 80, alignment: .leading)
            Text(description)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Inline Focus Mode View
struct InlineFocusModeView: View {
    @EnvironmentObject var documentManager: DocumentManager
    @StateObject private var timerManager = FocusTimerManager.shared
    
    @State private var showControls = true
    @State private var controlsTimer: Timer?
    @State private var backgroundColor: Color = Color(white: 0.08)
    @State private var textBrightness: Double = 1.0
    @State private var showTimer = true
    @State private var lastMouseLocation: CGPoint = .zero
    @State private var escKeyMonitor: Any?
    
    var body: some View {
        ZStack {
            // Dark background
            backgroundColor
                .ignoresSafeArea()
            
            // PDF View
            FocusModePDFView()
                .environmentObject(documentManager)
                .brightness(textBrightness - 1)
            
            // Invisible tracking area to detect mouse movement
            GeometryReader { geometry in
                Color.clear
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            // Show controls when mouse moves
                            if abs(location.x - lastMouseLocation.x) > 5 || abs(location.y - lastMouseLocation.y) > 5 {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showControls = true
                                }
                                resetHideTimer()
                            }
                            lastMouseLocation = location
                        case .ended:
                            // Start hide timer when mouse leaves
                            resetHideTimer()
                        }
                    }
            }
            
            // Overlay controls
            VStack {
                // Top bar - always visible area for exit button
                topControlBar
                    .opacity(showControls ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: showControls)
                
                Spacer()
                
                // Bottom bar with navigation and timer
                bottomBar
                    .opacity(showControls || showTimer ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: showControls)
            }
            
            // Exit hint at top center (always slightly visible)
            VStack {
                Text("Move mouse to show controls • Press ESC to exit")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(showControls ? 0 : 0.3))
                    .padding(.top, 8)
                    .animation(.easeInOut(duration: 0.3), value: showControls)
                Spacer()
            }
        }
        .onAppear {
            // Start reading session tracking
            if let name = documentManager.fileURL?.lastPathComponent {
                ReadingProgressManager.shared.startSession(
                    documentName: name,
                    totalPages: documentManager.pageCount
                )
            }
            // Start with controls visible, then hide after delay
            resetHideTimer()
            
            // Add ESC key monitoring
            escKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 { // ESC key
                    DispatchQueue.main.async {
                        documentManager.showFocusMode = false
                    }
                    return nil
                }
                return event
            }
        }
        .onDisappear {
            ReadingProgressManager.shared.endCurrentSession()
            controlsTimer?.invalidate()
            
            // Remove ESC key monitoring
            if let monitor = escKeyMonitor {
                NSEvent.removeMonitor(monitor)
                escKeyMonitor = nil
            }
        }
    }
    
    private func resetHideTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls = false
            }
        }
    }
    
    private var topControlBar: some View {
        HStack(spacing: 16) {
            // Exit Focus Mode button
            Button(action: { documentManager.showFocusMode = false }) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                    Text("Exit Focus Mode")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.8))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Page indicator
            Text("\(documentManager.currentPageIndex + 1) / \(documentManager.pageCount)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .cornerRadius(8)
            
            Spacer()
            
            // Settings menu
            Menu {
                Button(action: { showTimer.toggle() }) {
                    Label(showTimer ? "Hide Timer" : "Show Timer", systemImage: "timer")
                }
                
                Divider()
                
                Menu("Background") {
                    Button("Black") { backgroundColor = .black }
                    Button("Dark Gray") { backgroundColor = Color(white: 0.15) }
                    Button("Sepia") { backgroundColor = Color(red: 0.2, green: 0.18, blue: 0.12) }
                    Button("Dark Blue") { backgroundColor = Color(red: 0.05, green: 0.1, blue: 0.15) }
                }
                
                Menu("Brightness") {
                    ForEach([0.6, 0.8, 1.0, 1.2], id: \.self) { value in
                        Button("\(Int(value * 100))%") { textBrightness = value }
                    }
                }
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .cornerRadius(8)
            }
            .menuStyle(.borderlessButton)
        }
        .padding()
    }
    
    private var bottomBar: some View {
        HStack(spacing: 20) {
            // Navigation arrows
            HStack(spacing: 16) {
                Button(action: { documentManager.previousPage() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .disabled(documentManager.currentPageIndex <= 0)
                .opacity(documentManager.currentPageIndex <= 0 ? 0.4 : 1)
                
                Button(action: { documentManager.nextPage() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .disabled(documentManager.currentPageIndex >= documentManager.pageCount - 1)
                .opacity(documentManager.currentPageIndex >= documentManager.pageCount - 1 ? 0.4 : 1)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .cornerRadius(25)
            
            // Timer (if enabled)
            if showTimer {
                HStack(spacing: 12) {
                    // Progress ring
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 3)
                        Circle()
                            .trim(from: 0, to: timerManager.progress)
                            .stroke(Color(timerManager.mode.color), lineWidth: 3)
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 28, height: 28)
                    
                    // Time display
                    Text(timerManager.formattedTimeRemaining)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                    
                    // Play/Pause button
                    Button(action: {
                        if timerManager.state == .running {
                            timerManager.pause()
                        } else {
                            timerManager.start()
                        }
                    }) {
                        Image(systemName: timerManager.state == .running ? "pause.fill" : "play.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .cornerRadius(25)
            }
            
            // Reading progress
            if let progress = ReadingProgressManager.shared.getProgress(for: documentManager.fileName) {
                HStack(spacing: 8) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 12))
                    Text("\(Int(progress.progressPercentage))%")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .cornerRadius(25)
            }
        }
        .padding(.bottom, 30)
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(DocumentManager())
    }
}
