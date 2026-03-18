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
    @State private var showHighlighterPopover: Bool = false
    
    private let highlighterColors: [(String, PlatformColor)] = [
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
    
    struct ToolbarGroupModifier: ViewModifier {
        func body(content: Content) -> some View {
            content
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                )
                .overlay(
                    Capsule().stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
                )
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            
            // Group 1: Sidebar
            HStack(spacing: 8) {
                Button(action: { documentManager.toggleSidebar() }) {
                    Image(systemName: "sidebar.left")
                        .foregroundColor(documentManager.showSidebar ? .accentColor : .secondary)
                }
                .buttonStyle(.borderless)
                .help("Toggle Sidebar (⌥⌘S)")
            }
            .modifier(ToolbarGroupModifier())
            
            // Group 2: Navigation
            HStack(spacing: 8) {
                Button(action: { documentManager.previousPage() }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .disabled(!hasDocument || documentManager.currentPageIndex <= 0)
                .help("Previous Page")
                
                HStack(spacing: 4) {
                    if isEditingPage && hasDocument {
                        TextField("", text: $pageInputText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 40)
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
            .modifier(ToolbarGroupModifier())
            
            // Group 3: Zoom
            HStack(spacing: 10) {
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
            .modifier(ToolbarGroupModifier())
            
            // Group 4: Layout & View Modes
            HStack(spacing: 12) {
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
            .modifier(ToolbarGroupModifier())
            
            // Group 5: Tools (Highlight, Bookmark, Save, Print, Focus)
            HStack(spacing: 14) {
                Button(action: {
                    if documentManager.highlighterEnabled {
                        documentManager.highlighterEnabled = false
                    } else {
                        documentManager.highlighterEnabled = true
                        showHighlighterPopover = true
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "highlighter")
                            .font(.system(size: 14))
                            .foregroundColor(documentManager.highlighterEnabled ? .white : .primary)
                        
                        Circle()
                            .fill(Color(documentManager.highlighterColor))
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(documentManager.highlighterEnabled ? .white.opacity(0.8) : .secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(documentManager.highlighterEnabled ? Color.accentColor : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!hasDocument)
                .help("Highlighter (⌘H)")
                .popover(isPresented: $showHighlighterPopover, arrowEdge: .bottom) {
                    HighlighterPopoverContent(
                        documentManager: documentManager,
                        colors: highlighterColors,
                        showPicker: $showHighlighterColorPicker
                    )
                }
                
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
                    
                Button(action: {
                    documentManager.autoSaveEnabled.toggle()
                    if documentManager.autoSaveEnabled && documentManager.hasUnsavedChanges {
                        documentManager.saveDocument()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        if documentManager.autoSaveEnabled {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                        }
                    }
                    .foregroundColor(documentManager.autoSaveEnabled ? .green : .secondary)
                }
                .buttonStyle(.borderless)
                .help("Toggle Auto Save")
                .disabled(!hasDocument)
                
                Button(action: { documentManager.printDocument() }) {
                    Image(systemName: "printer")
                }
                .buttonStyle(.borderless)
                .help("Print (⌘P)")
                .disabled(!hasDocument)
                
                Button(action: { documentManager.showFocusMode.toggle() }) {
                    Image(systemName: documentManager.showFocusMode ? "eye.fill" : "eye")
                        .foregroundColor(documentManager.showFocusMode ? .accentColor : .secondary)
                }
                .buttonStyle(.borderless)
                .help(documentManager.showFocusMode ? "Exit Focus Mode" : "Focus Mode")
                .disabled(!hasDocument)
            }
            .modifier(ToolbarGroupModifier())
            
            Spacer()
            
            // Group 6: Search & Sidebar Right
            HStack(spacing: 12) {
                Button(action: { documentManager.toggleSearch() }) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(documentManager.showSearch ? .accentColor : .secondary)
                }
                .buttonStyle(.borderless)
                .help("Find (⌘F)")
                .disabled(!hasDocument)
                
                Button(action: { documentManager.toggleRightPanel() }) {
                    Image(systemName: "sidebar.right")
                        .foregroundColor(documentManager.showRightPanel ? .accentColor : .secondary)
                }
                .buttonStyle(.borderless)
                .help("Toggle Right Panel (⌥⌘R)")
            }
            .modifier(ToolbarGroupModifier())
            
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle()) // Make transparent areas clickable
        .onTapGesture(count: 2) {
            #if os(macOS)
            if let window = NSApplication.shared.windows.first(where: { $0.isKeyWindow }) {
                window.zoom(nil)
            }
            #endif
        }
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

// MARK: - Highlighter Popover Content
struct HighlighterPopoverContent: View {
    @ObservedObject var documentManager: DocumentManager
    let colors: [(String, PlatformColor)]
    @Binding var showPicker: Bool
    @Environment(\.dismiss) var dismiss
    
    let columns = [
        GridItem(.adaptive(minimum: 36, maximum: 36), spacing: 8)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Auto-Highlight Color")
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 4)
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(colors, id: \.0) { name, color in
                    Button(action: {
                        documentManager.highlighterColor = color
                        documentManager.highlighterEnabled = true
                        dismiss()
                    }) {
                        Circle()
                            .fill(Color(color))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                            )
                            .overlay(
                                documentManager.highlighterColor == color && documentManager.highlighterEnabled ? 
                                Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                                : nil
                            )
                    }
                    .buttonStyle(.plain)
                    .help(name)
                }
            }
            .padding(.horizontal, 4)
            
            Divider()
            
            Button(action: {
                dismiss()
                showPicker = true
            }) {
                HStack {
                    Image(systemName: "paintpalette")
                    Text("Custom Color...")
                    Spacer()
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
                .background(Color.primary.opacity(0.001)) // Make entire row clickable
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(width: 170)
    }
}

// MARK: - Highlighter Color Picker
struct HighlighterColorPickerSheet: View {
    let currentColor: PlatformColor
    let onApply: (PlatformColor) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var pickedColor: Color

    init(currentColor: PlatformColor, onApply: @escaping (PlatformColor) -> Void) {
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
                    onApply(PlatformColor(pickedColor))
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
