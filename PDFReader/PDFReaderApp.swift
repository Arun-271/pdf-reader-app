//
//  PDFReaderApp.swift
//  PDFReader
//
//  A cross-platform PDF reader application for macOS and iOS
//

import SwiftUI

@main
struct PDFReaderApp: App {
    @StateObject private var documentManager = DocumentManager()
    @StateObject private var bookmarkManager = BookmarkManager()
    @StateObject private var recentDocumentsManager = RecentDocumentsManager()
    @StateObject private var aiManager = AIAssistantManager()
    
    @State private var showRecentDocuments = false
    
    var body: some Scene {
        #if os(iOS)
        // iOS Window Group
        WindowGroup {
            ContentView_iOS()
                .environmentObject(documentManager)
                .environmentObject(bookmarkManager)
                .environmentObject(recentDocumentsManager)
                .environmentObject(aiManager)
        }
        #else
        // macOS Window Group
        WindowGroup {
            ContentView()
                .environmentObject(documentManager)
                .environmentObject(bookmarkManager)
                .environmentObject(recentDocumentsManager)
                .environmentObject(aiManager)
                .frame(minWidth: 900, minHeight: 700)
                .onAppear {
                    // Configure window appearance
                    configureWindowAppearance()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            // File menu
            CommandGroup(replacing: .newItem) {
                Button("Open...") {
                    documentManager.openDocument()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Open Recent...") {
                    showRecentDocuments = true
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Divider()

                Button("Close Document") {
                    documentManager.closeDocument()
                }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(documentManager.pdfDocument == nil)

                Divider()

                Button("Save") {
                    documentManager.saveDocument()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(documentManager.pdfDocument == nil)

                Button("Save As...") {
                    documentManager.saveDocumentAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(documentManager.pdfDocument == nil)

                Divider()

                Button("Print...") {
                    documentManager.printDocument()
                }
                .keyboardShortcut("p", modifiers: .command)
                .disabled(documentManager.pdfDocument == nil)
            }
            
            // Edit menu
            CommandGroup(replacing: .textEditing) {
                Button("Find...") {
                    documentManager.toggleSearch()
                }
                .keyboardShortcut("f", modifiers: .command)
                
                Divider()
                
                Button("Toggle Highlighter") {
                    documentManager.highlighterEnabled.toggle()
                }
                .keyboardShortcut("h", modifiers: .command)
            }
            
            // View menu
            CommandGroup(after: .toolbar) {
                Button("Zoom In") {
                    documentManager.zoomIn()
                }
                .keyboardShortcut("+", modifiers: .command)
                
                Button("Zoom Out") {
                    documentManager.zoomOut()
                }
                .keyboardShortcut("-", modifiers: .command)
                
                Button("Actual Size") {
                    documentManager.resetZoom()
                }
                .keyboardShortcut("0", modifiers: .command)
                
                Button("Zoom to Fit") {
                    documentManager.zoomToFit()
                }
                .keyboardShortcut("9", modifiers: .command)
                
                Divider()
                
                Button("Toggle Sidebar") {
                    documentManager.toggleSidebar()
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
                
                Button("Toggle Right Panel") {
                    documentManager.toggleRightPanel()
                }
                .keyboardShortcut("r", modifiers: [.command, .option])
                
                Divider()
                
                Button("Enter Full Screen") {
                    toggleFullScreen()
                }
                .keyboardShortcut("f", modifiers: [.command, .control])
                
                Divider()
                
                // Display modes
                Button("Single Page") {
                    documentManager.setDisplayMode(.singlePage)
                }
                
                Button("Single Page Continuous") {
                    documentManager.setDisplayMode(.singlePageContinuous)
                }
                
                Button("Two Pages") {
                    documentManager.setDisplayMode(.twoUp)
                }
                
                Button("Two Pages Continuous") {
                    documentManager.setDisplayMode(.twoUpContinuous)
                }
            }
            
            // Bookmarks menu
            CommandMenu("Bookmarks") {
                Button("Add Bookmark") {
                    bookmarkManager.addBookmark(
                        for: documentManager.fileName,
                        pageIndex: documentManager.currentPageIndex
                    )
                }
                .keyboardShortcut("d", modifiers: .command)
                .disabled(documentManager.pdfDocument == nil)
                
                Button("Remove Bookmark") {
                    bookmarkManager.removeBookmark(
                        for: documentManager.fileName,
                        at: documentManager.currentPageIndex
                    )
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                .disabled(!bookmarkManager.isBookmarked(
                    documentName: documentManager.fileName,
                    pageIndex: documentManager.currentPageIndex
                ))
                
                Divider()
                
                let bookmarks = bookmarkManager.bookmarks(for: documentManager.fileName)
                if bookmarks.isEmpty {
                    Text("No Bookmarks")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(bookmarks) { bookmark in
                        Button("Page \(bookmark.pageIndex + 1): \(bookmark.title)") {
                            documentManager.goToPage(bookmark.pageIndex)
                        }
                    }
                }
            }
            
            // Go menu
            CommandMenu("Go") {
                Button("Next Page") {
                    documentManager.nextPage()
                }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .disabled(documentManager.currentPageIndex >= documentManager.pageCount - 1)
                
                Button("Previous Page") {
                    documentManager.previousPage()
                }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .disabled(documentManager.currentPageIndex <= 0)
                
                Divider()
                
                Button("First Page") {
                    documentManager.firstPage()
                }
                .keyboardShortcut(.upArrow, modifiers: .command)
                
                Button("Last Page") {
                    documentManager.lastPage()
                }
                .keyboardShortcut(.downArrow, modifiers: .command)
            }
            
            // Tools menu
            CommandMenu("Tools") {
                Button("AI Assistant") {
                    documentManager.rightPanelMode = .ai
                    documentManager.showRightPanel = true
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                
                Button("Dictionary") {
                    documentManager.rightPanelMode = .dictionary
                    documentManager.showRightPanel = true
                }
                .keyboardShortcut("d", modifiers: [.command, .option])
                
                Button("Web Search") {
                    documentManager.rightPanelMode = .webSearch
                    documentManager.showRightPanel = true
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])
            }
        }
        
        Settings {
            SettingsView()
                .environmentObject(aiManager)
        }
        #endif
    }
    
    #if os(macOS)
    private func toggleFullScreen() {
        if let window = NSApplication.shared.windows.first {
            window.toggleFullScreen(nil)
        }
    }
    
    private func configureWindowAppearance() {
        // Configure window for modern appearance
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = NSApplication.shared.windows.first {
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.styleMask.insert(.fullSizeContentView)
                window.backgroundColor = NSColor.windowBackgroundColor
            }
        }
    }
    #endif
}
