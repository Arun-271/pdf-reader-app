//
//  PDFKitView_iOS.swift
//  PDFReader
//
//  iOS-specific PDFView wrapper
//

#if os(iOS)

import SwiftUI
import PDFKit

struct PDFKitView_iOS: UIViewRepresentable {
    @EnvironmentObject var documentManager: DocumentManager
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.usePageViewController(false)
        
        // Enable gestures
        pdfView.isUserInteractionEnabled = true
        
        // Set up delegate
        pdfView.delegate = context.coordinator
        
        // Store reference
        DispatchQueue.main.async {
            documentManager.pdfView = pdfView
        }
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        // Update document if changed
        if pdfView.document !== documentManager.pdfDocument {
            pdfView.document = documentManager.pdfDocument
        }
        
        // Update zoom
        let expectedScale = documentManager.scaleFactor
        if abs(pdfView.scaleFactor - expectedScale) > 0.01 {
            pdfView.scaleFactor = expectedScale
        }
        
        // Update display mode
        updateDisplayMode(pdfView)
        
        // Navigate to page if needed
        if let document = pdfView.document,
           let targetPage = document.page(at: documentManager.currentPageIndex),
           pdfView.currentPage != targetPage {
            pdfView.go(to: targetPage)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func updateDisplayMode(_ pdfView: PDFView) {
        switch documentManager.displayMode {
        case .singlePage:
            pdfView.displayMode = .singlePage
        case .singlePageContinuous:
            pdfView.displayMode = .singlePageContinuous
        case .twoUp:
            pdfView.displayMode = .twoUp
        case .twoUpContinuous:
            pdfView.displayMode = .twoUpContinuous
        @unknown default:
            pdfView.displayMode = .singlePageContinuous
        }
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, PDFViewDelegate {
        var parent: PDFKitView_iOS
        
        init(_ parent: PDFKitView_iOS) {
            self.parent = parent
        }
        
        func pdfViewPageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let document = pdfView.document else { return }
            
            let index = document.index(for: currentPage)
            
            DispatchQueue.main.async {
                self.parent.documentManager.currentPageIndex = index
            }
        }
    }
}

// MARK: - iOS Content View
struct ContentView_iOS: View {
    @EnvironmentObject var documentManager: DocumentManager
    @State private var showSidebar = false
    @State private var showRightPanel = false
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            IOSSidebarView()
        } detail: {
            // Main content
            ZStack {
                if documentManager.pdfDocument != nil {
                    PDFKitView_iOS()
                        .environmentObject(documentManager)
                } else {
                    IOSWelcomeView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showSidebar.toggle() }) {
                        Image(systemName: "sidebar.left")
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text(documentManager.fileName)
                        .font(.headline)
                        .lineLimit(1)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { documentManager.zoomIn() }) {
                            Label("Zoom In", systemImage: "plus.magnifyingglass")
                        }
                        Button(action: { documentManager.zoomOut() }) {
                            Label("Zoom Out", systemImage: "minus.magnifyingglass")
                        }
                        Divider()
                        Button(action: { showRightPanel.toggle() }) {
                            Label("AI Assistant", systemImage: "sparkles")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showRightPanel) {
            NavigationStack {
                AIAssistantView()
                    .navigationTitle("AI Assistant")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showRightPanel = false }
                        }
                    }
            }
        }
    }
}

// MARK: - iOS Sidebar
struct IOSSidebarView: View {
    @EnvironmentObject var documentManager: DocumentManager
    @EnvironmentObject var bookmarkManager: BookmarkManager
    
    var body: some View {
        List {
            // Recent Documents Section
            Section("Recent Documents") {
                ForEach(RecentDocumentsManager.shared.documents.prefix(5)) { doc in
                    Button(action: { openDocument(doc) }) {
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundColor(.red)
                            VStack(alignment: .leading) {
                                Text(doc.name)
                                    .lineLimit(1)
                                Text("\(doc.pageCount) pages")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            
            // Bookmarks Section
            if documentManager.pdfDocument != nil {
                Section("Bookmarks") {
                    let bookmarks = bookmarkManager.bookmarks(for: documentManager.fileName)
                    if bookmarks.isEmpty {
                        Text("No bookmarks")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(bookmarks) { bookmark in
                            Button(action: { documentManager.goToPage(bookmark.pageIndex) }) {
                                HStack {
                                    Image(systemName: "bookmark.fill")
                                        .foregroundColor(bookmarkColor(bookmark.color))
                                    Text(bookmark.title)
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Library")
    }
    
    private func openDocument(_ doc: RecentDocument) {
        if FileManager.default.fileExists(atPath: doc.url.path) {
            documentManager.loadDocument(from: doc.url)
        }
    }
    
    private func bookmarkColor(_ colorString: String) -> Color {
        switch colorString {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        default: return .accentColor
        }
    }
}

// MARK: - iOS Welcome View
struct IOSWelcomeView: View {
    @EnvironmentObject var documentManager: DocumentManager
    @State private var showFilePicker = false
    
    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 8) {
                Text("PDF Reader")
                    .font(.largeTitle.bold())
                Text("Open a PDF to get started")
                    .foregroundColor(.secondary)
            }
            
            Button(action: { showFilePicker = true }) {
                Label("Open PDF", systemImage: "folder")
                    .frame(maxWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    _ = url.startAccessingSecurityScopedResource()
                    documentManager.loadDocument(from: url)
                }
            case .failure(let error):
                print("Error opening file: \(error)")
            }
        }
    }
}

#endif
