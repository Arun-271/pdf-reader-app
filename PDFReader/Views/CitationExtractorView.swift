//
//  CitationExtractorView.swift
//  PDFReader
//
//  UI for extracting and exporting citations
//

import SwiftUI
import PDFKit

struct CitationExtractorView: View {
    @EnvironmentObject var documentManager: DocumentManager
    @StateObject private var extractor = CitationExtractor.shared
    @State private var selectedFormat: CitationFormat = .apa
    @State private var searchText = ""
    @State private var selectedCitations: Set<UUID> = []
    
    var filteredCitations: [ExtractedCitation] {
        if searchText.isEmpty {
            return extractor.extractedCitations
        }
        return extractor.extractedCitations.filter { citation in
            citation.rawText.localizedCaseInsensitiveContains(searchText) ||
            citation.title.localizedCaseInsensitiveContains(searchText) ||
            citation.authors.joined().localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with extract button
            headerSection
            
            Divider()
            
            if extractor.isExtracting {
                extractingView
            } else if extractor.extractedCitations.isEmpty {
                emptyState
            } else {
                citationsList
            }
            
            Divider()
            
            // Export options
            exportSection
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Citations")
                    .font(.headline)
                
                Spacer()
                
                Button(action: extractCitations) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("Extract")
                    }
                    .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(documentManager.pdfDocument == nil || extractor.isExtracting)
            }
            
            if !extractor.extractedCitations.isEmpty {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search citations...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.systemBackground)
                )
            }
        }
        .padding()
    }
    
    private var extractingView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ProgressView(value: extractor.progress) {
                Text("Extracting citations...")
                    .font(.caption)
            }
            .progressViewStyle(.linear)
            .padding(.horizontal, 40)
            
            Text("\(Int(extractor.progress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            
            Image(systemName: "quote.bubble")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No Citations Extracted")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Click 'Extract' to find citations\nin the references section")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
    }
    
    private var citationsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredCitations) { citation in
                    CitationRow(
                        citation: citation,
                        format: selectedFormat,
                        isSelected: selectedCitations.contains(citation.id),
                        onToggle: {
                            if selectedCitations.contains(citation.id) {
                                selectedCitations.remove(citation.id)
                            } else {
                                selectedCitations.insert(citation.id)
                            }
                        },
                        onNavigate: {
                            if let pageIndex = citation.pageIndex {
                                documentManager.goToPage(pageIndex)
                            }
                        }
                    )
                    .environmentObject(documentManager)
                }
            }
            .padding()
        }
    }
    
    private var exportSection: some View {
        VStack(spacing: 12) {
            // Format picker
            HStack {
                Text("Format:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("", selection: $selectedFormat) {
                    ForEach(CitationFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 250)
            }
            
            // Export buttons
            HStack(spacing: 12) {
                Button(action: copySelected) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                    }
                }
                .disabled(selectedCitations.isEmpty && extractor.extractedCitations.isEmpty)
                
                Button(action: copyAll) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc.fill")
                        Text("Copy All")
                    }
                }
                .disabled(extractor.extractedCitations.isEmpty)
                
                Button(action: exportToFile) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export")
                    }
                }
                .disabled(extractor.extractedCitations.isEmpty)
            }
            .font(.caption)
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func extractCitations() {
        guard let document = documentManager.pdfDocument else { return }
        
        Task {
            await extractor.extractCitations(from: document)
        }
    }
    
    private func copySelected() {
        let citations = extractor.extractedCitations.filter { selectedCitations.contains($0.id) }
        let text = citations.isEmpty
            ? extractor.exportCitations(format: selectedFormat)
            : citations.map { $0.formatted(as: selectedFormat) }.joined(separator: "\n\n")
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    
    private func copyAll() {
        extractor.copyToClipboard(format: selectedFormat)
    }
    
    private func exportToFile() {
        extractor.exportToFile(format: selectedFormat)
    }
}

struct CitationRow: View {
    @EnvironmentObject var documentManager: DocumentManager
    let citation: ExtractedCitation
    let format: CitationFormat
    let isSelected: Bool
    let onToggle: () -> Void
    let onNavigate: (() -> Void)?
    
    @State private var isExpanded = false
    @State private var isHovered = false
    
    init(citation: ExtractedCitation, format: CitationFormat, isSelected: Bool, onToggle: @escaping () -> Void, onNavigate: (() -> Void)? = nil) {
        self.citation = citation
        self.format = format
        self.isSelected = isSelected
        self.onToggle = onToggle
        self.onNavigate = onNavigate
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(alignment: .top, spacing: 8) {
                Button(action: onToggle) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    if !citation.title.isEmpty {
                        Text(citation.title)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(isExpanded ? nil : 2)
                    }
                    
                    // Authors
                    if !citation.authors.isEmpty {
                        Text(citation.authors.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    // Meta info
                    HStack(spacing: 8) {
                        // Navigate to page button
                        if let pageIndex = citation.pageIndex {
                            Button(action: {
                                onNavigate?()
                            }) {
                                HStack(spacing: 2) {
                                    Image(systemName: "arrow.right.circle")
                                        .font(.caption2)
                                    Text(citation.pageLabel ?? "Page \(pageIndex + 1)")
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.green.opacity(0.15))
                                )
                            }
                            .buttonStyle(.plain)
                            .help("Go to page")
                        }
                        
                        if let year = citation.year {
                            Text(year)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.blue.opacity(0.1))
                                )
                        }
                        
                        if let doi = citation.doi {
                            Button(action: { openDOI(doi) }) {
                                Text("DOI")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Spacer()
                
                // Expand/collapse
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Expanded view - formatted citation
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    Text("Formatted (\(format.rawValue)):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(citation.formatted(as: format))
                        .font(.system(size: 11))
                        .textSelection(.enabled)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.systemBackground)
                        )
                    
                    // Copy button
                    HStack {
                        Spacer()
                        Button(action: { copyCitation() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                Text("Copy")
                            }
                            .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? Color.accentColor.opacity(0.3) : Color.secondarySystemBackground)
        )
        .onHover { isHovered = $0 }
    }
    
    private func copyCitation() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(citation.formatted(as: format), forType: .string)
    }
    
    private func openDOI(_ doi: String) {
        if let url = URL(string: "https://doi.org/\(doi)") {
            NSWorkspace.shared.open(url)
        }
    }
}
