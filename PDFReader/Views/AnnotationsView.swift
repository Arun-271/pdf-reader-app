//
//  AnnotationsView.swift
//  PDFReader
//
//  Annotation tools and list view - Modern design with notes support
//

import SwiftUI
import PDFKit

// MARK: - Annotation Tool Enum
enum AnnotationTool: String, CaseIterable, Identifiable {
    case highlight = "Highlight"
    case underline = "Underline"
    case strikethrough = "Strike"
    case note = "Note"
    case freeText = "Text"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .highlight: return "highlighter"
        case .underline: return "underline"
        case .strikethrough: return "strikethrough"
        case .note: return "note.text"
        case .freeText: return "character.textbox"
        }
    }
    
    var pdfAnnotationType: PDFAnnotationSubtype {
        switch self {
        case .highlight: return .highlight
        case .underline: return .underline
        case .strikethrough: return .strikeOut
        case .note: return .text
        case .freeText: return .freeText
        }
    }
}

// MARK: - Filter Option
enum AnnotationFilter: String, CaseIterable {
    case all = "All"
    case highlights = "Highlights"
    case notes = "Notes"
    case currentPage = "This Page"
}

// MARK: - Main View
struct AnnotationsView: View {
    @EnvironmentObject var documentManager: DocumentManager
    @State private var selectedTool: AnnotationTool = .highlight
    @State private var selectedColor: NSColor = .systemYellow
    @State private var annotations: [PDFAnnotation] = []
    @State private var showColorPicker = false
    @State private var hoveredAnnotationID: ObjectIdentifier?
    @State private var searchText = ""
    @State private var selectedFilter: AnnotationFilter = .all
    @State private var editingAnnotation: PDFAnnotation?
    @State private var showAddNoteSheet = false
    @State private var newNoteText = ""
    
    private let presetColors: [NSColor] = [
        .systemYellow, .systemGreen, .systemBlue,
        .systemPink, .systemOrange, .systemPurple
    ]
    
    var hasSelection: Bool {
        documentManager.pdfView?.currentSelection != nil
    }
    
    var filteredAnnotations: [PDFAnnotation] {
        var result = annotations
        
        // Apply filter
        switch selectedFilter {
        case .all:
            break
        case .highlights:
            result = result.filter { ["Highlight", "Underline", "StrikeOut"].contains($0.type ?? "") }
        case .notes:
            result = result.filter { ["Text", "FreeText"].contains($0.type ?? "") }
        case .currentPage:
            if let currentPage = documentManager.pdfView?.currentPage {
                result = result.filter { $0.page == currentPage }
            }
        }
        
        // Apply search
        if !searchText.isEmpty {
            result = result.filter { annotation in
                if let contents = annotation.contents, contents.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                if let page = annotation.page,
                   let selection = page.selection(for: annotation.bounds),
                   let text = selection.string,
                   text.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                return false
            }
        }
        
        return result
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Quick Actions Bar
            quickActionsBar
            
            Divider()
            
            // Search & Filter
            searchAndFilterBar
            
            Divider()
            
            // Annotations List
            annotationsList
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .onAppear { refreshAnnotations() }
        .onChange(of: documentManager.currentPageIndex) { _ in refreshAnnotations() }
        .onReceive(NotificationCenter.default.publisher(for: .PDFAnnotationAdded)) { _ in
            refreshAnnotations()
        }
        .onReceive(NotificationCenter.default.publisher(for: .PDFAnnotationRemoved)) { _ in
            refreshAnnotations()
        }
        .sheet(isPresented: $showColorPicker) {
            ImprovedColorPickerSheet(selectedColor: $selectedColor)
        }
        .sheet(isPresented: $showAddNoteSheet) {
            AddNoteSheet(noteText: $newNoteText, color: selectedColor) { text in
                addQuickNote(text: text)
            }
        }
        .sheet(item: $editingAnnotation) { annotation in
            EditNoteSheet(annotation: annotation) { newText in
                updateAnnotationNote(annotation, newText: newText)
            }
        }
    }
    
    // MARK: - Quick Actions Bar
    private var quickActionsBar: some View {
        VStack(spacing: 10) {
            // Color selection row
            HStack(spacing: 8) {
                ForEach(presetColors, id: \.self) { color in
                    Button(action: { selectedColor = color }) {
                        Circle()
                            .fill(Color(color))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: selectedColor == color ? 2 : 0)
                            )
                            .overlay(
                                Circle()
                                    .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 2)
                                    .padding(-2)
                            )
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                Button(action: { showColorPicker = true }) {
                    Image(systemName: "paintpalette")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Custom Color")
            }
            
            // Quick action buttons
            HStack(spacing: 8) {
                QuickActionButton(
                    icon: "highlighter",
                    label: "Highlight",
                    isEnabled: hasSelection
                ) {
                    selectedTool = .highlight
                    addAnnotationToSelection()
                }
                
                Menu {
                    Button(action: { showAddNoteSheet = true }) {
                        Label("Add Note to Selection", systemImage: "text.badge.plus")
                    }
                    .disabled(!hasSelection)
                    
                    Divider()
                    
                    Button(action: {
                        documentManager.addNoteMode = true
                    }) {
                        Label("Click to Add Note", systemImage: "hand.tap")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: documentManager.addNoteMode ? "hand.tap.fill" : "note.text.badge.plus")
                            .font(.system(size: 11))
                        Text("Add Note")
                            .font(.system(size: 11, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(documentManager.addNoteMode ? Color.orange.opacity(0.2) : Color(NSColor.controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(documentManager.addNoteMode ? Color.orange : Color.clear, lineWidth: 1)
                    )
                }
                .menuStyle(.borderlessButton)
                .foregroundColor(documentManager.addNoteMode ? .orange : .primary)
                
                // Cancel button when in add note mode
                if documentManager.addNoteMode {
                    Button(action: { documentManager.addNoteMode = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
    }
    
    // MARK: - Search & Filter Bar
    private var searchAndFilterBar: some View {
        VStack(spacing: 8) {
            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                
                TextField("Search annotations...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.textBackgroundColor).opacity(0.5))
            .cornerRadius(8)
            
            // Filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(AnnotationFilter.allCases, id: \.self) { filter in
                        FilterPill(
                            title: filter.rawValue,
                            isSelected: selectedFilter == filter,
                            count: countForFilter(filter)
                        ) {
                            selectedFilter = filter
                        }
                    }
                }
            }
            
            // Stats bar
            HStack {
                Text("\(filteredAnnotations.count) annotation\(filteredAnnotations.count == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if !annotations.isEmpty {
                    Button("Clear All") {
                        clearAllAnnotations()
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.red.opacity(0.8))
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - Annotations List
    private var annotationsList: some View {
        Group {
            if annotations.isEmpty {
                emptyState
            } else if filteredAnnotations.isEmpty {
                noResultsState
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredAnnotations, id: \.self) { annotation in
                            EnhancedAnnotationCard(
                                annotation: annotation,
                                isHovered: hoveredAnnotationID == ObjectIdentifier(annotation),
                                onTap: { goToAnnotation(annotation) },
                                onEdit: { editingAnnotation = annotation },
                                onDelete: { removeAnnotation(annotation) }
                            )
                            .onHover { hovering in
                                hoveredAnnotationID = hovering ? ObjectIdentifier(annotation) : nil
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "pencil.tip.crop.circle")
                    .font(.system(size: 36))
                    .foregroundColor(.accentColor.opacity(0.7))
            }
            
            VStack(spacing: 6) {
                Text("No Annotations Yet")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Select text in the PDF and use the\nhighlight button, or add a note.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: { showAddNoteSheet = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Add Your First Note")
                }
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private var noResultsState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No matches found")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            Button("Clear Search") {
                searchText = ""
                selectedFilter = .all
            }
            .font(.system(size: 12))
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
            Spacer()
        }
    }
    
    // MARK: - Helper Functions
    private func countForFilter(_ filter: AnnotationFilter) -> Int {
        switch filter {
        case .all:
            return annotations.count
        case .highlights:
            return annotations.filter { ["Highlight", "Underline", "StrikeOut"].contains($0.type ?? "") }.count
        case .notes:
            return annotations.filter { ["Text", "FreeText"].contains($0.type ?? "") }.count
        case .currentPage:
            guard let currentPage = documentManager.pdfView?.currentPage else { return 0 }
            return annotations.filter { $0.page == currentPage }.count
        }
    }
    
    private func addQuickNote(text: String) {
        guard let pdfView = documentManager.pdfView,
              let page = pdfView.currentPage else { return }
        
        // Place note in center of visible area
        let visibleRect = pdfView.convert(pdfView.visibleRect, to: page)
        let noteRect = CGRect(
            x: visibleRect.midX - 10,
            y: visibleRect.midY - 10,
            width: 20,
            height: 20
        )
        
        let annotation = PDFAnnotation(bounds: noteRect, forType: .text, withProperties: nil)
        annotation.color = selectedColor
        annotation.contents = text
        page.addAnnotation(annotation)
        
        refreshAnnotations()
        newNoteText = ""
        NotificationCenter.default.post(name: .PDFAnnotationAdded, object: nil)
    }
    
    private func updateAnnotationNote(_ annotation: PDFAnnotation, newText: String) {
        annotation.contents = newText
        refreshAnnotations()
        
        // Force PDFView redraw
        if let pdfView = documentManager.pdfView {
            pdfView.setNeedsDisplay(pdfView.bounds)
        }
    }
    
    private func clearAllAnnotations() {
        guard let document = documentManager.pdfDocument else { return }
        
        for i in 0..<document.pageCount {
            if let page = document.page(at: i) {
                let toRemove = page.annotations.filter { 
                    ["Highlight", "Underline", "StrikeOut", "Text", "FreeText"].contains($0.type ?? "")
                }
                toRemove.forEach { page.removeAnnotation($0) }
            }
        }
        
        refreshAnnotations()
        
        if let pdfView = documentManager.pdfView {
            pdfView.setNeedsDisplay(pdfView.bounds)
        }
        
        NotificationCenter.default.post(name: .PDFAnnotationRemoved, object: nil)
    }
    
    // MARK: - Actions
    private func addAnnotationToSelection() {
        guard let pdfView = documentManager.pdfView,
              let selection = pdfView.currentSelection,
              let page = selection.pages.first else { return }

        let bounds = selection.bounds(for: page)
        let annotation: PDFAnnotation

        // Check for stacking on markup annotations and merge if overlapping
        let markupTypes: [AnnotationTool] = [.highlight, .underline, .strikethrough]
        if markupTypes.contains(selectedTool) {
            let typeString: String
            switch selectedTool {
            case .highlight: typeString = "Highlight"
            case .underline: typeString = "Underline"
            case .strikethrough: typeString = "StrikeOut"
            default: typeString = ""
            }
            let overlapping = page.annotations.filter { existing in
                existing.type == typeString && existing.bounds.intersects(bounds)
            }

            if !overlapping.isEmpty {
                // Merge: union all overlapping + new selection
                var unionRect = bounds
                for existing in overlapping {
                    unionRect = unionRect.union(existing.bounds)
                }
                for existing in overlapping {
                    page.removeAnnotation(existing)
                }
                let annotColor: NSColor = selectedTool == .highlight ? selectedColor.withAlphaComponent(0.5) : selectedColor
                annotation = PDFAnnotation(bounds: unionRect, forType: selectedTool.pdfAnnotationType, withProperties: nil)
                annotation.color = annotColor
                page.addAnnotation(annotation)
                pdfView.clearSelection()
                refreshAnnotations()
                NotificationCenter.default.post(name: .PDFAnnotationAdded, object: nil)
                return
            }
        }

        switch selectedTool {
        case .highlight:
            annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
            annotation.color = selectedColor.withAlphaComponent(0.5)

        case .underline:
            annotation = PDFAnnotation(bounds: bounds, forType: .underline, withProperties: nil)
            annotation.color = selectedColor

        case .strikethrough:
            annotation = PDFAnnotation(bounds: bounds, forType: .strikeOut, withProperties: nil)
            annotation.color = selectedColor

        case .note:
            let noteRect = CGRect(x: bounds.maxX, y: bounds.maxY - 20, width: 20, height: 20)
            annotation = PDFAnnotation(bounds: noteRect, forType: .text, withProperties: nil)
            annotation.color = selectedColor
            annotation.contents = "Note"

        case .freeText:
            annotation = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
            annotation.color = selectedColor
            annotation.contents = selection.string ?? ""
            annotation.font = NSFont.systemFont(ofSize: 12)
        }

        page.addAnnotation(annotation)
        pdfView.clearSelection()
        refreshAnnotations()
        NotificationCenter.default.post(name: .PDFAnnotationAdded, object: nil)
    }
    
    private func refreshAnnotations() {
        guard let document = documentManager.pdfDocument else {
            annotations = []
            return
        }
        
        var result: [PDFAnnotation] = []
        let validTypes = ["Highlight", "Underline", "StrikeOut", "Text", "FreeText"]
        
        for i in 0..<document.pageCount {
            if let page = document.page(at: i) {
                let filtered = page.annotations.filter { validTypes.contains($0.type ?? "") }
                result.append(contentsOf: filtered)
            }
        }
        annotations = result
    }
    
    private func goToAnnotation(_ annotation: PDFAnnotation) {
        guard let page = annotation.page else { return }
        documentManager.pdfView?.go(to: annotation.bounds, on: page)
    }
    
    private func removeAnnotation(_ annotation: PDFAnnotation) {
        guard let page = annotation.page else { return }
        page.removeAnnotation(annotation)

        // Force PDFView to redraw so the annotation visually disappears
        if let pdfView = documentManager.pdfView {
            pdfView.setNeedsDisplay(pdfView.bounds)
        }

        refreshAnnotations()

        // Post notification so other views can react to annotation removal
        NotificationCenter.default.post(name: .PDFAnnotationRemoved, object: nil)
    }
}

// MARK: - Tool Button
struct ToolButton: View {
    let tool: AnnotationTool
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tool.icon)
                    .font(.system(size: 16))
                    .frame(height: 20)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .help(tool.rawValue)
    }
}

// MARK: - Quick Action Button
struct QuickActionButton: View {
    let icon: String
    let label: String
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isEnabled ? Color.accentColor : Color.gray.opacity(0.3))
            .foregroundColor(isEnabled ? .white : .secondary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

// MARK: - Filter Pill
struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.3) : Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Enhanced Annotation Card
struct EnhancedAnnotationCard: View {
    let annotation: PDFAnnotation
    let isHovered: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var isExpanded = false
    
    private var typeLabel: String {
        switch annotation.type {
        case "Highlight": return "Highlight"
        case "Underline": return "Underline"
        case "StrikeOut": return "Strikethrough"
        case "Text": return "Note"
        case "FreeText": return "Text"
        default: return "Annotation"
        }
    }
    
    private var typeIcon: String {
        switch annotation.type {
        case "Highlight": return "highlighter"
        case "Underline": return "underline"
        case "StrikeOut": return "strikethrough"
        case "Text": return "note.text"
        case "FreeText": return "character.textbox"
        default: return "pencil"
        }
    }
    
    private var annotationText: String? {
        if let contents = annotation.contents, !contents.isEmpty {
            return contents
        }
        guard let page = annotation.page else { return nil }
        if let selection = page.selection(for: annotation.bounds) {
            let text = selection.string ?? ""
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }
    
    private var pageNumber: Int? {
        guard let page = annotation.page,
              let document = page.document else { return nil }
        for i in 0..<document.pageCount {
            if document.page(at: i) == page { return i + 1 }
        }
        return nil
    }
    
    private var isNoteType: Bool {
        ["Text", "FreeText"].contains(annotation.type ?? "")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                // Color indicator & type icon
                ZStack {
                    Circle()
                        .fill(Color(annotation.color).opacity(0.3))
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: typeIcon)
                        .font(.system(size: 12))
                        .foregroundColor(Color(annotation.color))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(typeLabel)
                        .font(.system(size: 12, weight: .semibold))
                    
                    if let page = pageNumber {
                        Text("Page \(page)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Action buttons (visible on hover)
                if isHovered {
                    HStack(spacing: 4) {
                        if isNoteType {
                            Button(action: onEdit) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 11))
                                    .foregroundColor(.accentColor)
                                    .frame(width: 24, height: 24)
                                    .background(Color.accentColor.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .help("Edit Note")
                        }
                        
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundColor(.red)
                                .frame(width: 24, height: 24)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .help("Delete")
                    }
                }
            }
            
            // Content preview
            if let text = annotationText {
                Text(text)
                    .font(.system(size: 11))
                    .foregroundColor(.primary.opacity(0.8))
                    .lineLimit(isExpanded ? nil : 2)
                    .padding(.top, 8)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }
                
                if text.count > 80 && !isExpanded {
                    Text("Show more...")
                        .font(.system(size: 10))
                        .foregroundColor(.accentColor)
                        .padding(.top, 4)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? Color(NSColor.selectedContentBackgroundColor).opacity(0.15) : Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(annotation.color).opacity(0.3), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .contextMenu {
            Button("Go to Annotation", action: onTap)
            if isNoteType {
                Button("Edit Note", action: onEdit)
            }
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}

// MARK: - Add Note Sheet
struct AddNoteSheet: View {
    @Binding var noteText: String
    let color: NSColor
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "note.text.badge.plus")
                    .font(.system(size: 18))
                    .foregroundColor(.accentColor)
                Text("Add Note")
                    .font(.headline)
                Spacer()
            }
            
            // Text editor
            TextEditor(text: $noteText)
                .font(.system(size: 13))
                .frame(minHeight: 120)
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                )
                .focused($isFocused)
            
            // Color indicator
            HStack {
                Text("Color:")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Circle()
                    .fill(Color(color))
                    .frame(width: 16, height: 16)
                Spacer()
            }
            
            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Add Note") {
                    if !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onSave(noteText)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
        .onAppear {
            isFocused = true
        }
    }
}

// MARK: - Edit Note Sheet
struct EditNoteSheet: View {
    let annotation: PDFAnnotation
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var noteText: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "pencil")
                    .font(.system(size: 18))
                    .foregroundColor(.accentColor)
                Text("Edit Note")
                    .font(.headline)
                Spacer()
            }
            
            // Text editor
            TextEditor(text: $noteText)
                .font(.system(size: 13))
                .frame(minHeight: 120)
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                )
                .focused($isFocused)
            
            // Annotation info
            HStack {
                Circle()
                    .fill(Color(annotation.color))
                    .frame(width: 12, height: 12)
                
                if let page = annotation.page,
                   let doc = page.document {
                    let pageIndex = (0..<doc.pageCount).first { doc.page(at: $0) == page } ?? 0
                    Text("Page \(pageIndex + 1)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Save") {
                    onSave(noteText)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 360)
        .onAppear {
            noteText = annotation.contents ?? ""
            isFocused = true
        }
    }
}

// Make PDFAnnotation Identifiable for sheet presentation
extension PDFAnnotation: @retroactive Identifiable {
    public var id: ObjectIdentifier {
        ObjectIdentifier(self)
    }
}

// MARK: - Color Dot
struct ColorDot: View {
    let color: NSColor
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(color))
                .frame(width: 22, height: 22)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
                )
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2)
                        .padding(-1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Annotation Row
struct AnnotationRow: View {
    let annotation: PDFAnnotation
    let isHovered: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    
    private var typeLabel: String {
        switch annotation.type {
        case "Highlight": return "Highlight"
        case "Underline": return "Underline"
        case "StrikeOut": return "Strikethrough"
        case "Text": return "Note"
        case "FreeText": return "Text"
        default: return "Annotation"
        }
    }

    private var annotationText: String? {
        // For notes and freeText, use the contents
        if let contents = annotation.contents, !contents.isEmpty {
            return contents
        }
        // For highlights/underlines/strikeouts, extract text from the page at the annotation bounds
        guard let page = annotation.page else { return nil }
        if let selection = page.selection(for: annotation.bounds) {
            let text = selection.string ?? ""
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }
    
    private var pageNumber: Int? {
        guard let page = annotation.page,
              let document = page.document else { return nil }
        for i in 0..<document.pageCount {
            if document.page(at: i) == page { return i + 1 }
        }
        return nil
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(annotation.color))
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 2) {
                if let text = annotationText {
                    Text(text)
                        .font(.system(size: 11))
                        .lineLimit(2)
                } else {
                    Text(typeLabel)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                }
            }
            
            Spacer(minLength: 4)
            
            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Delete")
            } else if let page = pageNumber {
                Text("p.\(page)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color(NSColor.selectedContentBackgroundColor).opacity(0.3) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .contextMenu {
            Button("Go to Annotation", action: onTap)
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}

// MARK: - Color Picker Sheet
struct ColorPickerSheet: View {
    @Binding var selectedColor: NSColor
    @Environment(\.dismiss) private var dismiss
    @State private var pickedColor: Color = .yellow
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Custom Color")
                .font(.headline)
            
            ColorPicker("", selection: $pickedColor, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 180, height: 80)
            
            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                
                Button("Apply") {
                    selectedColor = NSColor(pickedColor)
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

// MARK: - NSColor Extension
extension NSColor {
    func isApproximatelyEqual(to other: NSColor) -> Bool {
        guard let c1 = self.usingColorSpace(.deviceRGB),
              let c2 = other.usingColorSpace(.deviceRGB) else { return false }
        let tolerance: CGFloat = 0.01
        return abs(c1.redComponent - c2.redComponent) < tolerance &&
               abs(c1.greenComponent - c2.greenComponent) < tolerance &&
               abs(c1.blueComponent - c2.blueComponent) < tolerance
    }
}
