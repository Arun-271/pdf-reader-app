//
//  SelectionToolbarView.swift
//  PDFReader
//
//  Floating toolbar that appears when text is selected
//

import SwiftUI
import PDFKit

// MARK: - Selection Toolbar Window Controller
class SelectionToolbarController: NSObject, ObservableObject {
    static let shared = SelectionToolbarController()
    
    @Published var isVisible = false
    @Published var position = CGPoint.zero
    @Published var selectedText = ""
    @Published var hasExistingHighlight = false
    @Published var existingAnnotation: PDFAnnotation?
    
    private var toolbarWindow: NSWindow?
    private var hostingView: NSHostingView<SelectionToolbarContent>?
    weak var pdfView: PDFView?
    weak var documentManager: DocumentManager?
    
    private override init() {
        super.init()
    }
    
    func show(at point: CGPoint, in pdfView: PDFView, documentManager: DocumentManager) {
        self.pdfView = pdfView
        self.documentManager = documentManager
        
        guard let selection = pdfView.currentSelection,
              let text = selection.string,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            hide()
            return
        }
        
        selectedText = text
        
        // Check for existing highlight on selection
        checkForExistingHighlight(selection: selection)
        
        // Calculate screen position
        let screenPoint = pdfView.window?.convertPoint(toScreen: pdfView.convert(point, to: nil)) ?? point
        
        if toolbarWindow == nil {
            createWindow()
        } else {
            // Update content when showing again
            updateContent()
        }
        
        // Position the window above the selection
        let windowFrame = NSRect(x: screenPoint.x - 175, y: screenPoint.y + 20, width: 350, height: 50)
        toolbarWindow?.setFrame(windowFrame, display: true)
        toolbarWindow?.orderFront(nil)
        
        isVisible = true
    }
    
    private func checkForExistingHighlight(selection: PDFSelection) {
        hasExistingHighlight = false
        existingAnnotation = nil
        
        guard let page = selection.pages.first else { return }
        let bounds = selection.bounds(for: page)
        
        // Check if selection overlaps with existing highlight/underline/strikeout
        for annotation in page.annotations {
            let validTypes = ["Highlight", "Underline", "StrikeOut"]
            guard validTypes.contains(annotation.type ?? "") else { continue }
            
            if annotation.bounds.intersects(bounds) {
                hasExistingHighlight = true
                existingAnnotation = annotation
                break
            }
        }
    }
    
    func showAtSelection() {
        guard let pdfView = pdfView,
              let selection = pdfView.currentSelection,
              let page = selection.pages.first else {
            hide()
            return
        }
        
        let bounds = selection.bounds(for: page)
        let point = CGPoint(x: bounds.midX, y: bounds.maxY)
        let convertedPoint = pdfView.convert(point, from: page)
        
        show(at: convertedPoint, in: pdfView, documentManager: documentManager!)
    }
    
    func hide() {
        toolbarWindow?.orderOut(nil)
        isVisible = false
    }
    
    private func createWindow() {
        let contentView = SelectionToolbarContent(controller: self)
        hostingView = NSHostingView(rootView: contentView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 50),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.contentView = hostingView
        window.backgroundColor = .clear
        window.isOpaque = false
        window.level = .floating
        window.hasShadow = true
        window.isMovableByWindowBackground = false
        
        toolbarWindow = window
    }
    
    private func updateContent() {
        let contentView = SelectionToolbarContent(controller: self)
        hostingView?.rootView = contentView
    }
    
    // MARK: - Actions
    
    func highlightSelection(color: NSColor) {
        guard let pdfView = pdfView as? HighlightablePDFView else { return }
        UserDefaults.standard.setColor(color, forKey: "lastHighlightColor")
        addAnnotation(type: .highlight, color: color.withAlphaComponent(0.5))
        hide()
    }
    
    func removeHighlight() {
        guard let annotation = existingAnnotation,
              let page = annotation.page else { return }
        
        page.removeAnnotation(annotation)
        
        if let pdfView = pdfView {
            pdfView.setNeedsDisplay(pdfView.bounds)
        }
        
        NotificationCenter.default.post(name: .PDFAnnotationRemoved, object: pdfView)
        hide()
    }
    
    func underlineSelection() {
        addAnnotation(type: .underline, color: .systemBlue)
        hide()
    }
    
    func strikethroughSelection() {
        addAnnotation(type: .strikeOut, color: .systemRed)
        hide()
    }
    
    func addNote() {
        guard let pdfView = pdfView,
              let selection = pdfView.currentSelection,
              let page = selection.pages.first else { return }
        
        let bounds = selection.bounds(for: page)
        
        // Create a note annotation
        let noteAnnotation = PDFAnnotation(bounds: CGRect(x: bounds.maxX + 5, y: bounds.midY - 12, width: 24, height: 24), forType: .text, withProperties: nil)
        noteAnnotation.contents = selectedText
        noteAnnotation.color = .systemYellow
        page.addAnnotation(noteAnnotation)
        
        pdfView.clearSelection()
        NotificationCenter.default.post(name: .PDFAnnotationAdded, object: pdfView)
        hide()
    }
    
    func copyText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(selectedText, forType: .string)
        hide()
    }
    
    func askAI() {
        // Send to AI assistant
        documentManager?.rightPanelMode = .ai
        documentManager?.showRightPanel = true
        // Could also set the text as a query
        hide()
    }
    
    private func addAnnotation(type: PDFAnnotationSubtype, color: NSColor) {
        guard let pdfView = pdfView,
              let selection = pdfView.currentSelection else { return }
        
        // Get selections by line
        let lineSelections = selection.selectionsByLine() ?? [selection]
        
        for lineSelection in lineSelections {
            for page in lineSelection.pages {
                let bounds = lineSelection.bounds(for: page)
                guard bounds.width > 0 && bounds.height > 0 else { continue }
                
                let annotation = PDFAnnotation(bounds: bounds, forType: type, withProperties: nil)
                annotation.color = color
                page.addAnnotation(annotation)
            }
        }
        
        pdfView.clearSelection()
        NotificationCenter.default.post(name: .PDFAnnotationAdded, object: pdfView)
    }
}

// MARK: - Toolbar Content View
struct SelectionToolbarContent: View {
    @ObservedObject var controller: SelectionToolbarController
    
    private let colors: [NSColor] = [
        .systemYellow, .systemGreen, .systemBlue, .systemPink, .systemOrange, .systemPurple
    ]
    
    var body: some View {
        HStack(spacing: 6) {
            // Show remove button if already highlighted
            if controller.hasExistingHighlight {
                Button(action: { controller.removeHighlight() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                        Text("Remove")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.red.opacity(0.8))
                    )
                }
                .buttonStyle(.plain)
                .help("Remove Highlight")
                
                Divider()
                    .frame(height: 24)
            }
            
            // Color buttons
            ForEach(colors, id: \.self) { color in
                Button(action: { controller.highlightSelection(color: color) }) {
                    Circle()
                        .fill(Color(color))
                        .frame(width: 26, height: 26)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
                .help("Highlight \(colorName(color))")
            }
            
            Divider()
                .frame(height: 24)
            
            // Underline
            Button(action: { controller.underlineSelection() }) {
                Image(systemName: "underline")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.gray.opacity(0.4)))
            }
            .buttonStyle(.plain)
            .help("Underline")
            
            // Add Note
            Button(action: { controller.addNote() }) {
                Image(systemName: "note.text.badge.plus")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.orange.opacity(0.7)))
            }
            .buttonStyle(.plain)
            .help("Add Note")
            
            Divider()
                .frame(height: 24)
            
            // Ask AI
            Button(action: { controller.askAI() }) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(width: 26, height: 26)
                .background(
                    Circle()
                        .fill(Color.purple.opacity(0.8))
                )
            }
            .buttonStyle(.plain)
            .help("Ask AI about selection")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.95))
                .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
    
    private func colorName(_ color: NSColor) -> String {
        switch color {
        case .systemYellow: return "Yellow"
        case .systemGreen: return "Green"
        case .systemBlue: return "Blue"
        case .systemPink: return "Pink"
        case .systemOrange: return "Orange"
        case .systemPurple: return "Purple"
        default: return "Color"
        }
    }
}
