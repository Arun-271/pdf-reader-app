//
//  DocumentManager.swift
//  PDFReader
//
//  Manages PDF document state and operations
//

import SwiftUI
import PDFKit
import Combine

enum SidebarMode: String, CaseIterable {
    case thumbnails = "Thumbnails"
    case bookmarks = "Bookmarks"
    case annotations = "Annotations"
}

enum RightPanelMode: String, CaseIterable {
    case ai = "AI"
    case dictionary = "Dictionary"
    case webSearch = "Web"
    case citations = "Citations"
    case ocr = "OCR"
    case timer = "Timer"
    case progress = "Progress"
    case cloud = "Cloud"
    case googleDrive = "Drive"
}

class DocumentManager: ObservableObject {
    @Published var pdfDocument: PDFDocument?
    @Published var currentPageIndex: Int = 0
    @Published var scaleFactor: CGFloat = 1.0
    @Published var showSidebar: Bool = true
    @Published var showRightPanel: Bool = false
    @Published var showSearch: Bool = false
    @Published var searchText: String = ""
    @Published var searchResults: [PDFSelection] = []
    @Published var currentSearchIndex: Int = 0
    @Published var fileName: String = "No Document"
    @Published var fileURL: URL?
    @Published var displayMode: PDFDisplayMode = .singlePageContinuous
    @Published var sidebarMode: SidebarMode = .thumbnails
    @Published var rightPanelMode: RightPanelMode = .ai
    @Published var continuousScroll: Bool = true
    
    // Highlighter mode
    @Published var highlighterEnabled: Bool = false
    @Published var highlighterColor: NSColor = .systemYellow
    
    // Focus mode
    @Published var showFocusMode: Bool = false
    
    // Note adding mode
    @Published var addNoteMode: Bool = false
    @Published var noteColor: NSColor = .systemYellow
    
    // Save state
    @Published var hasUnsavedChanges: Bool = false
    @Published var showSavePrompt: Bool = false
    @Published var autoSaveEnabled: Bool = false
    
    var pdfView: PDFView?
    
    var pageCount: Int {
        pdfDocument?.pageCount ?? 0
    }
    
    var currentPage: PDFPage? {
        guard let document = pdfDocument, currentPageIndex < document.pageCount else { return nil }
        return document.page(at: currentPageIndex)
    }
    
    func openDocument() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Choose a PDF file to open"
        panel.prompt = "Open"
        
        if panel.runModal() == .OK, let url = panel.url {
            loadDocument(from: url)
        }
    }
    
    func loadDocument(from url: URL) {
        if let document = PDFDocument(url: url) {
            self.pdfDocument = document
            self.currentPageIndex = 0
            self.fileName = url.lastPathComponent
            self.fileURL = url
            self.scaleFactor = 1.0
            self.searchResults = []
            self.searchText = ""
            self.hasUnsavedChanges = false
            
            // Set continuous scroll mode
            if continuousScroll {
                displayMode = .singlePageContinuous
            }
            
            setupAnnotationObservers()
        }
    }
    
    private func setupAnnotationObservers() {
        NotificationCenter.default.removeObserver(self, name: .PDFAnnotationAdded, object: nil)
        NotificationCenter.default.removeObserver(self, name: .PDFAnnotationRemoved, object: nil)
        
        NotificationCenter.default.addObserver(forName: .PDFAnnotationAdded, object: nil, queue: .main) { [weak self] _ in
            self?.markAsChanged()
        }
        
        NotificationCenter.default.addObserver(forName: .PDFAnnotationRemoved, object: nil, queue: .main) { [weak self] _ in
            self?.markAsChanged()
        }
    }
    
    private func markAsChanged() {
        if !hasUnsavedChanges {
            hasUnsavedChanges = true
        }
        if autoSaveEnabled {
            saveDocument()
        }
    }
    
    func saveDocument() {
        guard let document = pdfDocument, let url = fileURL else { return }
        document.write(to: url)
        hasUnsavedChanges = false
    }

    func saveDocumentAs() {
        guard let document = pdfDocument else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = fileName
        if panel.runModal() == .OK, let url = panel.url {
            document.write(to: url)
            fileURL = url
            fileName = url.lastPathComponent
            hasUnsavedChanges = false
        }
    }

    func closeDocumentRequested() {
        guard pdfDocument != nil else { return }
        
        if hasUnsavedChanges && !autoSaveEnabled {
            showSavePrompt = true
        } else {
            if autoSaveEnabled && hasUnsavedChanges {
                saveDocument()
            }
            closeDocument()
        }
    }

    func closeDocument() {
        pdfDocument = nil
        currentPageIndex = 0
        fileName = "No Document"
        fileURL = nil
        scaleFactor = 1.0
        searchResults = []
        searchText = ""
        showSearch = false
        highlighterEnabled = false
        hasUnsavedChanges = false
        showSavePrompt = false
    }

    func toggleRightPanel() {
        showRightPanel.toggle()
    }
    
    func printDocument() {
        guard let pdfView = pdfView, let document = pdfDocument else { return }
        
        let printInfo = NSPrintInfo.shared
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .fit
        
        if let printOperation = document.printOperation(for: printInfo, scalingMode: .pageScaleToFit, autoRotate: true) {
            printOperation.showsPrintPanel = true
            printOperation.showsProgressPanel = true
            printOperation.run()
        }
    }
    
    func goToPage(_ index: Int) {
        guard let document = pdfDocument else { return }
        if index >= 0 && index < document.pageCount {
            currentPageIndex = index
            if let page = document.page(at: index) {
                pdfView?.go(to: page)
            }
        }
    }
    
    func nextPage() {
        let increment = (displayMode == .twoUp || displayMode == .twoUpContinuous) ? 2 : 1
        goToPage(currentPageIndex + increment)
    }
    
    func previousPage() {
        let decrement = (displayMode == .twoUp || displayMode == .twoUpContinuous) ? 2 : 1
        goToPage(currentPageIndex - decrement)
    }
    
    func firstPage() {
        goToPage(0)
    }
    
    func lastPage() {
        goToPage(pageCount - 1)
    }
    
    func zoomIn() {
        scaleFactor = min(scaleFactor * 1.25, 5.0)
        pdfView?.scaleFactor = scaleFactor
    }
    
    func zoomOut() {
        scaleFactor = max(scaleFactor / 1.25, 0.25)
        pdfView?.scaleFactor = scaleFactor
    }
    
    func resetZoom() {
        scaleFactor = 1.0
        pdfView?.scaleFactor = scaleFactor
    }
    
    func zoomToFit() {
        pdfView?.autoScales = true
        if let scale = pdfView?.scaleFactor {
            scaleFactor = scale
        }
    }
    
    func toggleSidebar() {
        showSidebar.toggle()
    }
    
    func toggleSearch() {
        showSearch.toggle()
        if !showSearch {
            clearSearch()
        }
    }
    
    func performSearch() {
        guard let document = pdfDocument, !searchText.isEmpty else {
            searchResults = []
            return
        }
        
        searchResults = []
        currentSearchIndex = 0
        
        // Find all occurrences - findString returns [PDFSelection]
        searchResults = document.findString(searchText, withOptions: .caseInsensitive)
        
        // Highlight first result
        if let firstResult = searchResults.first {
            highlightSelection(firstResult)
        }
    }
    
    func nextSearchResult() {
        guard !searchResults.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex + 1) % searchResults.count
        highlightSelection(searchResults[currentSearchIndex])
    }
    
    func previousSearchResult() {
        guard !searchResults.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex - 1 + searchResults.count) % searchResults.count
        highlightSelection(searchResults[currentSearchIndex])
    }
    
    func highlightSelection(_ selection: PDFSelection) {
        pdfView?.setCurrentSelection(selection, animate: true)
        pdfView?.scrollSelectionToVisible(nil)
        
        // Update current page index
        if let page = selection.pages.first, let document = pdfDocument {
            let index = document.index(for: page)
            currentPageIndex = index
        }
    }
    
    func clearSearch() {
        searchText = ""
        searchResults = []
        currentSearchIndex = 0
        pdfView?.highlightedSelections = nil
    }
    
    func setDisplayMode(_ mode: PDFDisplayMode) {
        displayMode = mode
        pdfView?.displayMode = mode
    }
}

// Extension to support drag and drop
extension DocumentManager {
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        if provider.hasItemConformingToTypeIdentifier("com.adobe.pdf") {
            provider.loadItem(forTypeIdentifier: "com.adobe.pdf", options: nil) { [weak self] item, error in
                if let url = item as? URL {
                    DispatchQueue.main.async {
                        self?.loadDocument(from: url)
                    }
                }
            }
            return true
        }
        
        if provider.hasItemConformingToTypeIdentifier("public.file-url") {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { [weak self] item, error in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil),
                   url.pathExtension.lowercased() == "pdf" {
                    DispatchQueue.main.async {
                        self?.loadDocument(from: url)
                    }
                }
            }
            return true
        }
        
        return false
    }
}
