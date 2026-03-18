//
//  ToolbarView.swift
//  PDFReader
//
//  Custom toolbar with navigation and zoom controls
//

import SwiftUI
import PDFKit

struct ToolbarView: View {
    @EnvironmentObject var documentManager: DocumentManager
    @EnvironmentObject var bookmarkManager: BookmarkManager
    @State private var pageInputText: String = ""
    @State private var isEditingPage: Bool = false
    @State private var showHighlighterColorPicker: Bool = false
    
    private let highlighterColors: [(String, NSColor)] = [
        ("Yellow", .systemYellow),
        ("Green", .systemGreen),
        ("Blue", .systemBlue),
        ("Pink", .systemPink),
        ("Orange", .systemOrange),
        ("Purple", .systemPurple)
    ]
    
    var isCurrentPageBookmarked: Bool {
        bookmarkManager.isBookmarked(
            documentName: documentManager.fileName,
            pageIndex: documentManager.currentPageIndex
        )
    }
    
    var hasDocument: Bool {
        documentManager.pdfDocument != nil
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Sidebar toggle
            Button(action: { documentManager.toggleSidebar() }) {
                Image(systemName: "sidebar.left")
                    .foregroundColor(documentManager.showSidebar ? .accentColor : .secondary)
            }
            .buttonStyle(.borderless)
            .help("Toggle Sidebar (⌥⌘S)")
            
            Divider()
                .frame(height: 20)
            
            // Navigation controls
            HStack(spacing: 6) {
                Button(action: { documentManager.previousPage() }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .disabled(!hasDocument || documentManager.currentPageIndex <= 0)
                .help("Previous Page")
                
                // Page number display
                HStack(spacing: 4) {
                    if isEditingPage && hasDocument {
                        TextField("", text: $pageInputText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                            .multilineTextAlignment(.center)
                            .onSubmit {
                                if let page = Int(pageInputText) {
                                    documentManager.goToPage(page - 1)
                                }
                                isEditingPage = false
                            }
                    } else {
                        Text(hasDocument ? "\(documentManager.currentPageIndex + 1)" : "-")
                            .frame(width: 30)
                            .onTapGesture {
                                if hasDocument {
                                    pageInputText = "\(documentManager.currentPageIndex + 1)"
                                    isEditingPage = true
                                }
                            }
                    }
                    
                    Text("of \(hasDocument ? documentManager.pageCount : 0)")
                        .foregroundColor(.secondary)
                }
                .font(.system(.body, design: .monospaced))
                
                Button(action: { documentManager.nextPage() }) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
                .disabled(!hasDocument || documentManager.currentPageIndex >= documentManager.pageCount - 1)
                .help("Next Page")
            }
            
            Divider()
                .frame(height: 20)
            
            // Zoom controls
            HStack(spacing: 6) {
                Button(action: { documentManager.zoomOut() }) {
                    Image(systemName: "minus.magnifyingglass")
                }
                .buttonStyle(.borderless)
                .disabled(!hasDocument)
                .help("Zoom Out (⌘-)")
                
                Text("\(Int(documentManager.scaleFactor * 100))%")
                    .frame(width: 45)
                    .font(.system(.caption, design: .monospaced))
                
                Button(action: { documentManager.zoomIn() }) {
                    Image(systemName: "plus.magnifyingglass")
                }
                .buttonStyle(.borderless)
                .disabled(!hasDocument)
                .help("Zoom In (⌘+)")
                
                Button(action: { documentManager.zoomToFit() }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.borderless)
                .disabled(!hasDocument)
                .help("Zoom to Fit")
            }
            
            Divider()
                .frame(height: 20)
            
            // Page layout controls
            HStack(spacing: 4) {
                Button(action: { documentManager.setDisplayMode(.singlePage) }) {
                    Image(systemName: "doc")
                        .foregroundColor(documentManager.displayMode == .singlePage ? .accentColor : .secondary)
                }
                .buttonStyle(.borderless)
                .help("Single Page")
                
                Button(action: { documentManager.setDisplayMode(.singlePageContinuous) }) {
                    Image(systemName: "doc.text")
                        .foregroundColor(documentManager.displayMode == .singlePageContinuous ? .accentColor : .secondary)
                }
                .buttonStyle(.borderless)
                .help("Single Page Continuous")
                
                Button(action: { documentManager.setDisplayMode(.twoUp) }) {
                    Image(systemName: "book")
                        .foregroundColor(documentManager.displayMode == .twoUp ? .accentColor : .secondary)
                }
                .buttonStyle(.borderless)
                .help("Two Pages")
                
                Button(action: { documentManager.setDisplayMode(.twoUpContinuous) }) {
                    Image(systemName: "book.pages")
                        .foregroundColor(documentManager.displayMode == .twoUpContinuous ? .accentColor : .secondary)
                }
                .buttonStyle(.borderless)
                .help("Two Pages Continuous")
            }
            .disabled(!hasDocument)
            
            Divider()
                .frame(height: 20)
            
            // Highlighter with color indicator and dropdown
            Menu {
                // Toggle highlighter
                Button(action: {
                    documentManager.highlighterEnabled.toggle()
                }) {
                    HStack {
                        Text(documentManager.highlighterEnabled ? "Disable Auto-Highlight" : "Enable Auto-Highlight")
                        if documentManager.highlighterEnabled {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Divider()

                // Color options
                ForEach(highlighterColors, id: \.1) { name, color in
                    Button(action: {
                        documentManager.highlighterColor = color
                        documentManager.highlighterEnabled = true
                    }) {
                        HStack {
                            Image(systemName: "circle.fill")
                                .foregroundColor(Color(color))
                            Text(name)
                            if documentManager.highlighterColor == color && documentManager.highlighterEnabled {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                Divider()

                Button(action: {
                    showHighlighterColorPicker = true
                }) {
                    HStack {
                        Image(systemName: "paintpalette")
                        Text("Custom Color...")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    // Highlighter icon with colored circle
                    Image(systemName: "highlighter")
                        .font(.system(size: 14))
                        .foregroundColor(documentManager.highlighterEnabled ? .primary : .secondary)
                    
                    // Color circle indicator - always visible
                    Circle()
                        .fill(Color(documentManager.highlighterColor))
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.3), lineWidth: 0.5)
                        )
                    
                    // Dropdown chevron
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(documentManager.highlighterEnabled ? Color.accentColor.opacity(0.15) : Color.clear)
                )
            }
            .menuStyle(.borderlessButton)
            .frame(width: 50)
            .disabled(!hasDocument)
            .help("Highlighter (⌘H)")
            
            Divider()
                .frame(height: 20)
            
            // Bookmark toggle
            Button(action: {
                bookmarkManager.toggleBookmark(
                    for: documentManager.fileName,
                    pageIndex: documentManager.currentPageIndex
                )
            }) {
                Image(systemName: isCurrentPageBookmarked ? "bookmark.fill" : "bookmark")
                    .foregroundColor(isCurrentPageBookmarked ? .accentColor : .secondary)
            }
            .buttonStyle(.borderless)
            .help("Toggle Bookmark (⌘D)")
            .disabled(!hasDocument)
            
            // Print button
            Button(action: { documentManager.printDocument() }) {
                Image(systemName: "printer")
            }
            .buttonStyle(.borderless)
            .help("Print (⌘P)")
            .disabled(documentManager.pdfDocument == nil)
            
            // Focus Mode toggle
            Button(action: { documentManager.showFocusMode.toggle() }) {
                Image(systemName: documentManager.showFocusMode ? "eye.fill" : "eye")
                    .foregroundColor(documentManager.showFocusMode ? .accentColor : .secondary)
            }
            .buttonStyle(.borderless)
            .help(documentManager.showFocusMode ? "Exit Focus Mode" : "Focus Mode")
            .disabled(!hasDocument)
            
            Spacer()
            
            // Search toggle
            Button(action: { documentManager.toggleSearch() }) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(documentManager.showSearch ? .accentColor : .secondary)
            }
            .buttonStyle(.borderless)
            .help("Find (⌘F)")
            .disabled(documentManager.pdfDocument == nil)
            
            Divider()
                .frame(height: 20)
            
            // Right panel toggle only (tools are inside the panel)
            Button(action: { documentManager.toggleRightPanel() }) {
                Image(systemName: "sidebar.right")
                    .foregroundColor(documentManager.showRightPanel ? .accentColor : .secondary)
            }
            .buttonStyle(.borderless)
            .help("Toggle Right Panel (⌥⌘R)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .sheet(isPresented: $showHighlighterColorPicker) {
            HighlighterColorPickerSheet(
                currentColor: documentManager.highlighterColor,
                onApply: { color in
                    documentManager.highlighterColor = color
                    documentManager.highlighterEnabled = true
                }
            )
        }
    }
}

// MARK: - Highlighter Color Picker
struct HighlighterColorPickerSheet: View {
    let currentColor: NSColor
    let onApply: (NSColor) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var pickedColor: Color

    init(currentColor: NSColor, onApply: @escaping (NSColor) -> Void) {
        self.currentColor = currentColor
        self.onApply = onApply
        _pickedColor = State(initialValue: Color(currentColor))
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Highlighter Color")
                .font(.headline)

            ColorPicker("", selection: $pickedColor, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 180, height: 80)

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("Apply") {
                    onApply(NSColor(pickedColor))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 240)
    }
}

struct ToolbarView_Previews: PreviewProvider {
    static var previews: some View {
        ToolbarView()
            .environmentObject(DocumentManager())
            .environmentObject(BookmarkManager())
    }
}
