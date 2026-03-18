//
//  PDFKitView.swift
//  PDFReader
//
//  SwiftUI wrapper for PDFKit's PDFView
//

import SwiftUI
import PDFKit
import ObjectiveC

// Wrapper class to hold associated object
private class AnnotationHolder {
    weak var annotation: PDFAnnotation?
    init(_ annotation: PDFAnnotation) {
        self.annotation = annotation
    }
}

private var pendingAnnotationKey: UInt8 = 0

// Custom PDFView with context menu for highlighting
class HighlightablePDFView: PDFView {
    weak var documentManager: DocumentManager?
    var onAnnotationAdded: (() -> Void)?
    private var selectionObserver: NSObjectProtocol?
    private var selectionToolbarTimer: Timer?
    private let selectionToolbar = SelectionToolbarController.shared

    deinit {
        selectionToolbarTimer?.invalidate()
        if let observer = selectionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func setupSelectionObserver() {
        selectionObserver = NotificationCenter.default.addObserver(
            forName: .PDFViewSelectionChanged,
            object: self,
            queue: .main
        ) { [weak self] _ in
            self?.handleSelectionChange()
        }
    }

    private func handleSelectionChange() {
        guard let documentManager = documentManager else { return }
        
        selectionToolbarTimer?.invalidate()
        selectionToolbarTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
            guard let self = self,
                  let selection = self.currentSelection,
                  let text = selection.string,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let page = selection.pages.first else {
                self?.selectionToolbar.hide()
                return
            }
            
            // If highlighter is enabled in toolbar, apply it immediately
            if let dm = self.documentManager, dm.highlighterEnabled {
                self.addHighlightAnnotation(color: dm.highlighterColor)
                return
            }
            
            // Show floating toolbar above selection
            self.selectionToolbar.pdfView = self
            self.selectionToolbar.documentManager = documentManager
            self.selectionToolbar.showAtSelection()
        }
    }
    
    override func rightMouseDown(with event: NSEvent) {
        // Hide floating toolbar when right-clicking
        selectionToolbar.hide()
        super.rightMouseDown(with: event)
    }
    
    override func mouseDown(with event: NSEvent) {
        // Hide toolbar when clicking
        selectionToolbar.hide()
        
        // Check if we're in add note mode
        if documentManager?.addNoteMode == true {
            handleAddNoteClick(with: event)
            return
        }
        
        super.mouseDown(with: event)
    }
    
    private func handleAddNoteClick(with event: NSEvent) {
        let locationInView = convert(event.locationInWindow, from: nil)
        
        guard let clickedPage = page(for: locationInView, nearest: false) else {
            super.mouseDown(with: event)
            return
        }
        
        let locationInPage = convert(locationInView, to: clickedPage)
        
        // Create a note annotation at click location
        let noteSize: CGFloat = 24
        let noteBounds = CGRect(
            x: locationInPage.x - noteSize / 2,
            y: locationInPage.y - noteSize / 2,
            width: noteSize,
            height: noteSize
        )
        
        let noteAnnotation = PDFAnnotation(bounds: noteBounds, forType: .text, withProperties: nil)
        noteAnnotation.color = documentManager?.noteColor ?? .systemYellow
        noteAnnotation.contents = ""
        noteAnnotation.iconType = .note
        
        clickedPage.addAnnotation(noteAnnotation)
        
        // Exit note mode after adding
        documentManager?.addNoteMode = false
        
        // Post notification to refresh annotations
        NotificationCenter.default.post(name: Notification.Name("AnnotationAdded"), object: noteAnnotation)
        
        // Show edit popup for the note
        showNoteEditPopover(for: noteAnnotation, at: locationInView)
    }
    
    private func showNoteEditPopover(for annotation: PDFAnnotation, at point: CGPoint) {
        // Create a popover for note editing
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 250, height: 150)
        
        let noteView = NoteEditPopoverView(annotation: annotation) {
            popover.close()
        }
        popover.contentViewController = NSHostingController(rootView: noteView)
        
        let rect = NSRect(origin: point, size: CGSize(width: 1, height: 1))
        popover.show(relativeTo: rect, of: self, preferredEdge: .maxY)
    }
    
    private func makeColorSwatchImage(color: NSColor, size: CGFloat = 16) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        color.setFill()
        let path = NSBezierPath(roundedRect: NSRect(x: 1, y: 1, width: size - 2, height: size - 2), xRadius: 3, yRadius: 3)
        path.fill()
        NSColor.separatorColor.setStroke()
        path.lineWidth = 0.5
        path.stroke()
        image.unlockFocus()
        return image
    }

    private var allHighlightColors: [(String, NSColor)] {
        var colors: [(String, NSColor)] = [
            ("Yellow", .systemYellow),
            ("Green", .systemGreen),
            ("Blue", .systemBlue),
            ("Pink", .systemPink),
            ("Orange", .systemOrange),
            ("Purple", .systemPurple)
        ]
        // Add saved custom colors
        let saved = SavedColorsManager.shared.colors
        for (i, color) in saved.enumerated() {
            colors.append(("Custom \(i + 1)", color))
        }
        return colors
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()

        // Check if user right-clicked on an existing annotation
        let locationInView = convert(event.locationInWindow, from: nil)
        var hitAnnotation: PDFAnnotation?
        if let clickedPage = page(for: locationInView, nearest: false) {
            let locationInPage = convert(locationInView, to: clickedPage)
            hitAnnotation = clickedPage.annotations.first { annotation in
                let validTypes = ["Highlight", "Underline", "StrikeOut", "Text", "FreeText"]
                return validTypes.contains(annotation.type ?? "") && annotation.bounds.contains(locationInPage)
            }
        }

        if let annotation = hitAnnotation {
            let typeLabel: String
            switch annotation.type {
            case "Highlight": typeLabel = "Highlight"
            case "Underline": typeLabel = "Underline"
            case "StrikeOut": typeLabel = "Strikethrough"
            case "Text": typeLabel = "Note"
            case "FreeText": typeLabel = "Text"
            default: typeLabel = "Annotation"
            }

            // Change color submenu for highlight/underline/strikeout
            if ["Highlight", "Underline", "StrikeOut"].contains(annotation.type ?? "") {
                let changeColorItem = NSMenuItem(title: "Change Color", action: nil, keyEquivalent: "")
                changeColorItem.image = NSImage(systemSymbolName: "paintpalette", accessibilityDescription: "Change Color")
                let colorMenu = NSMenu()

                for (name, color) in allHighlightColors {
                    let item = NSMenuItem(title: name, action: #selector(changeAnnotationColor(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = ["annotation": annotation, "color": color]
                    item.image = makeColorSwatchImage(color: color)
                    colorMenu.addItem(item)
                }

                colorMenu.addItem(NSMenuItem.separator())
                let customItem = NSMenuItem(title: "Custom Color...", action: #selector(changeAnnotationCustomColor(_:)), keyEquivalent: "")
                customItem.target = self
                customItem.representedObject = annotation
                customItem.image = NSImage(systemSymbolName: "plus.circle", accessibilityDescription: "Custom")
                colorMenu.addItem(customItem)

                changeColorItem.submenu = colorMenu
                menu.addItem(changeColorItem)
            }

            let deleteItem = NSMenuItem(title: "Delete \(typeLabel)", action: #selector(deleteAnnotationFromMenu(_:)), keyEquivalent: "")
            deleteItem.target = self
            deleteItem.representedObject = annotation
            deleteItem.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete")
            menu.addItem(deleteItem)
            menu.addItem(NSMenuItem.separator())
        }

        // Check if there's a text selection
        if let selection = currentSelection, let selectionString = selection.string, !selectionString.isEmpty {
            // Highlight submenu with color swatches
            let highlightItem = NSMenuItem(title: "Highlight", action: nil, keyEquivalent: "")
            highlightItem.image = NSImage(systemSymbolName: "highlighter", accessibilityDescription: "Highlight")
            let highlightMenu = NSMenu()

            for (name, color) in allHighlightColors {
                let item = NSMenuItem(title: name, action: #selector(highlightWithColor(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = color
                item.image = makeColorSwatchImage(color: color)
                highlightMenu.addItem(item)
            }

            highlightMenu.addItem(NSMenuItem.separator())
            let customItem = NSMenuItem(title: "Custom Color...", action: #selector(highlightWithCustomColor(_:)), keyEquivalent: "")
            customItem.target = self
            customItem.image = NSImage(systemSymbolName: "plus.circle", accessibilityDescription: "Custom")
            highlightMenu.addItem(customItem)

            highlightItem.submenu = highlightMenu
            menu.addItem(highlightItem)

            // Quick highlight with last used color
            let lastColor = UserDefaults.standard.color(forKey: "lastHighlightColor") ?? .systemYellow
            let quickHighlight = NSMenuItem(title: "Quick Highlight", action: #selector(quickHighlight(_:)), keyEquivalent: "h")
            quickHighlight.keyEquivalentModifierMask = [.command]
            quickHighlight.target = self
            quickHighlight.image = makeColorSwatchImage(color: lastColor)
            menu.addItem(quickHighlight)

            menu.addItem(NSMenuItem.separator())

            // Underline
            let underlineItem = NSMenuItem(title: "Underline", action: #selector(underlineSelection(_:)), keyEquivalent: "")
            underlineItem.target = self
            underlineItem.image = NSImage(systemSymbolName: "underline", accessibilityDescription: "Underline")
            menu.addItem(underlineItem)

            // Strikethrough
            let strikeItem = NSMenuItem(title: "Strikethrough", action: #selector(strikethroughSelection(_:)), keyEquivalent: "")
            strikeItem.target = self
            strikeItem.image = NSImage(systemSymbolName: "strikethrough", accessibilityDescription: "Strikethrough")
            menu.addItem(strikeItem)

            menu.addItem(NSMenuItem.separator())
            
            // Add Note
            let noteItem = NSMenuItem(title: "Add Note", action: #selector(addNoteToSelection(_:)), keyEquivalent: "")
            noteItem.target = self
            noteItem.image = NSImage(systemSymbolName: "note.text.badge.plus", accessibilityDescription: "Add Note")
            menu.addItem(noteItem)

            menu.addItem(NSMenuItem.separator())

            // Copy
            let copyItem = NSMenuItem(title: "Copy", action: #selector(copy(_:)), keyEquivalent: "c")
            copyItem.target = self
            menu.addItem(copyItem)
            
            // Summarize with AI
            let summarizeItem = NSMenuItem(title: "Summarize", action: #selector(summarizeSelection(_:)), keyEquivalent: "")
            summarizeItem.target = self
            summarizeItem.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Summarize")
            menu.addItem(summarizeItem)
        }

        if menu.items.isEmpty {
            return super.menu(for: event)
        }

        return menu
    }
    
    @objc func deleteAnnotationFromMenu(_ sender: NSMenuItem) {
        guard let annotation = sender.representedObject as? PDFAnnotation,
              let page = annotation.page else { return }
        page.removeAnnotation(annotation)
        setNeedsDisplay(bounds)
        NotificationCenter.default.post(name: .PDFAnnotationRemoved, object: self)
    }
    
    @objc func changeAnnotationColor(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: Any],
              let annotation = info["annotation"] as? PDFAnnotation,
              let color = info["color"] as? NSColor else { return }
        
        // Update annotation color
        if annotation.type == "Highlight" {
            annotation.color = color.withAlphaComponent(0.5)
        } else {
            annotation.color = color
        }
        
        setNeedsDisplay(bounds)
        NotificationCenter.default.post(name: .PDFAnnotationAdded, object: self)
    }
    
    @objc func changeAnnotationCustomColor(_ sender: NSMenuItem) {
        guard let annotation = sender.representedObject as? PDFAnnotation else { return }
        
        // Store annotation reference for color panel callback
        let holder = AnnotationHolder(annotation)
        objc_setAssociatedObject(self, &pendingAnnotationKey, holder, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        let colorPanel = NSColorPanel.shared
        colorPanel.setTarget(self)
        colorPanel.setAction(#selector(colorPanelDidSelectColorForAnnotation(_:)))
        colorPanel.orderFront(nil)
    }
    
    @objc func colorPanelDidSelectColorForAnnotation(_ sender: NSColorPanel) {
        guard let holder = objc_getAssociatedObject(self, &pendingAnnotationKey) as? AnnotationHolder,
              let annotation = holder.annotation else { return }
        
        let color = sender.color
        SavedColorsManager.shared.addColor(color)
        
        if annotation.type == "Highlight" {
            annotation.color = color.withAlphaComponent(0.5)
        } else {
            annotation.color = color
        }
        
        setNeedsDisplay(bounds)
        NSColorPanel.shared.orderOut(nil)
        NotificationCenter.default.post(name: .PDFAnnotationAdded, object: self)
        
        // Clear reference
        objc_setAssociatedObject(self, &pendingAnnotationKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    @objc func highlightWithColor(_ sender: NSMenuItem) {
        guard let color = sender.representedObject as? NSColor else { return }
        addHighlightAnnotation(color: color)
    }
    
    @objc func highlightWithCustomColor(_ sender: NSMenuItem) {
        let colorPanel = NSColorPanel.shared
        colorPanel.setTarget(self)
        colorPanel.setAction(#selector(colorPanelDidSelectColor(_:)))
        colorPanel.orderFront(nil)
    }
    
    @objc func colorPanelDidSelectColor(_ sender: NSColorPanel) {
        SavedColorsManager.shared.addColor(sender.color)
        addHighlightAnnotation(color: sender.color)
        NSColorPanel.shared.orderOut(nil)
    }
    
    @objc func quickHighlight(_ sender: Any?) {
        let lastColor = UserDefaults.standard.color(forKey: "lastHighlightColor") ?? .systemYellow
        addHighlightAnnotation(color: lastColor)
    }
    
    @objc func underlineSelection(_ sender: Any?) {
        addAnnotation(type: .underline, color: .systemBlue)
    }
    
    @objc func strikethroughSelection(_ sender: Any?) {
        addAnnotation(type: .strikeOut, color: .systemRed)
    }
    
    @objc func addNoteToSelection(_ sender: Any?) {
        guard let selection = currentSelection,
              let page = selection.pages.first,
              let selectedText = selection.string else { return }
        
        let bounds = selection.bounds(for: page)
        
        // Create a note annotation near the selection
        let noteAnnotation = PDFAnnotation(
            bounds: CGRect(x: bounds.maxX + 5, y: bounds.midY - 12, width: 24, height: 24),
            forType: .text,
            withProperties: nil
        )
        noteAnnotation.contents = selectedText
        noteAnnotation.color = .systemYellow
        page.addAnnotation(noteAnnotation)
        
        clearSelection()
        NotificationCenter.default.post(name: .PDFAnnotationAdded, object: self)
    }
    
    @objc func summarizeSelection(_ sender: Any?) {
        // Open AI panel and set context
        documentManager?.rightPanelMode = .ai
        documentManager?.showRightPanel = true
    }
    
    private func addHighlightAnnotation(color: NSColor) {
        // Save as last used color
        UserDefaults.standard.setColor(color, forKey: "lastHighlightColor")
        addAnnotation(type: .highlight, color: color.withAlphaComponent(0.5))
    }
    
    private func addAnnotation(type: PDFAnnotationSubtype, color: NSColor) {
        guard let selection = currentSelection else { return }

        let typeString: String
        switch type {
        case .highlight: typeString = "Highlight"
        case .underline: typeString = "Underline"
        case .strikeOut: typeString = "StrikeOut"
        default: typeString = ""
        }

        // Get selections by line to avoid merging across lines
        let lineSelections = selection.selectionsByLine() ?? [selection]
        
        for lineSelection in lineSelections {
            for page in lineSelection.pages {
                let bounds = lineSelection.bounds(for: page)
                guard bounds.width > 0 && bounds.height > 0 else { continue }

                if !typeString.isEmpty {
                    // Only merge annotations on the SAME line (similar Y position)
                    let lineThreshold: CGFloat = bounds.height * 0.5
                    let overlapping = page.annotations.filter { existing in
                        guard existing.type == typeString else { return false }
                        // Check if on same line (Y positions are close)
                        let yDiff = abs(existing.bounds.midY - bounds.midY)
                        return yDiff < lineThreshold && existing.bounds.intersects(bounds.insetBy(dx: -2, dy: 0))
                    }

                    if !overlapping.isEmpty {
                        // Check if selection is entirely within an existing annotation (avoid re-creating)
                        let fullyContained = overlapping.contains { existing in
                            existing.bounds.contains(bounds)
                        }
                        
                        if fullyContained && overlapping.count == 1 {
                            // Selection is inside existing annotation - don't create duplicate
                            continue
                        }
                        
                        // Compute the union of overlapping annotations + new selection (only horizontal merge)
                        var unionRect = bounds
                        for existing in overlapping {
                            // Merge horizontally only if on the same line
                            let minX = min(unionRect.minX, existing.bounds.minX)
                            let maxX = max(unionRect.maxX, existing.bounds.maxX)
                            unionRect = CGRect(x: minX, y: bounds.minY, width: maxX - minX, height: bounds.height)
                        }

                        // Remove all overlapping annotations (they'll be merged)
                        for existing in overlapping {
                            page.removeAnnotation(existing)
                        }

                        // Create a single merged annotation covering the range on this line
                        let merged = PDFAnnotation(bounds: unionRect, forType: type, withProperties: nil)
                        merged.color = color
                        page.addAnnotation(merged)
                        continue
                    }
                }

                let annotation = PDFAnnotation(bounds: bounds, forType: type, withProperties: nil)
                annotation.color = color
                page.addAnnotation(annotation)
            }
        }

        clearSelection()
        onAnnotationAdded?()

        // Post notification for annotation views to refresh
        NotificationCenter.default.post(name: .PDFAnnotationAdded, object: self)
    }
}

// Custom notifications for annotation changes
extension Notification.Name {
    static let PDFAnnotationAdded = Notification.Name("PDFAnnotationAdded")
    static let PDFAnnotationRemoved = Notification.Name("PDFAnnotationRemoved")
}

// UserDefaults extension for color storage
extension UserDefaults {
    func setColor(_ color: NSColor, forKey key: String) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false) {
            set(data, forKey: key)
        }
    }
    
    func color(forKey key: String) -> NSColor? {
        guard let data = data(forKey: key) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
    }
}

struct PDFKitView: NSViewRepresentable {
    @EnvironmentObject var documentManager: DocumentManager
    
    func makeNSView(context: Context) -> HighlightablePDFView {
        let pdfView = HighlightablePDFView()
        
        // Configure PDFView with modern styling
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = NSColor.windowBackgroundColor
        pdfView.displaysPageBreaks = true
        pdfView.pageBreakMargins = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        
        // Enable user interaction
        pdfView.acceptsDraggedFiles = true
        
        // Store reference
        pdfView.documentManager = documentManager
        documentManager.pdfView = pdfView
        
        // Set up selection observer for auto-highlight
        pdfView.setupSelectionObserver()
        
        // Set up notification observer for page changes
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        
        // Set up notification observer for scale changes (trackpad zoom)
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scaleChanged(_:)),
            name: .PDFViewScaleChanged,
            object: pdfView
        )
        
        return pdfView
    }
    
    func updateNSView(_ pdfView: HighlightablePDFView, context: Context) {
        // Update document if changed
        if pdfView.document !== documentManager.pdfDocument {
            pdfView.document = documentManager.pdfDocument
            pdfView.autoScales = true
            
            // Store initial scale factor
            if let scaleFactor = pdfView.scaleFactor as CGFloat? {
                DispatchQueue.main.async {
                    documentManager.scaleFactor = scaleFactor
                }
            }
        }
        
        // Update display mode
        if pdfView.displayMode != documentManager.displayMode {
            pdfView.displayMode = documentManager.displayMode
        }
        
        // Enhance double page spread by setting displaysAsBook
        let isTwoUp = documentManager.displayMode == .twoUp || documentManager.displayMode == .twoUpContinuous
        if pdfView.displaysAsBook != isTwoUp {
            pdfView.displaysAsBook = isTwoUp
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: PDFKitView
        
        init(_ parent: PDFKitView) {
            self.parent = parent
        }
        
        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let document = pdfView.document else { return }
            
            if let index = document.index(for: currentPage) as Int? {
                DispatchQueue.main.async {
                    self.parent.documentManager.currentPageIndex = index
                }
            }
        }
        
        @objc func scaleChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView else { return }
            
            DispatchQueue.main.async {
                self.parent.documentManager.scaleFactor = pdfView.scaleFactor
            }
        }
    }
}

// MARK: - Drop Delegate for PDF files
struct PDFDropDelegate: DropDelegate {
    @Binding var documentManager: DocumentManager
    
    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [.pdf, .fileURL])
    }
    
    func performDrop(info: DropInfo) -> Bool {
        return documentManager.handleDrop(providers: info.itemProviders(for: [.pdf, .fileURL]))
    }
}

// MARK: - Note Edit Popover View
struct NoteEditPopoverView: View {
    let annotation: PDFAnnotation
    let onDismiss: () -> Void
    
    @State private var noteText: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(.orange)
                Text("Quick Note")
                    .font(.headline)
                Spacer()
            }
            
            TextEditor(text: $noteText)
                .font(.system(size: 13))
                .frame(height: 80)
                .padding(6)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .focused($isFocused)
            
            HStack {
                Button("Cancel") {
                    // Remove the annotation if cancelled with no text
                    if noteText.isEmpty {
                        annotation.page?.removeAnnotation(annotation)
                    }
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Save") {
                    annotation.contents = noteText
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .onAppear {
            noteText = annotation.contents ?? ""
            isFocused = true
        }
    }
}
