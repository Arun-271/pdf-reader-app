//
//  OCRView.swift
//  PDFReader
//
//  OCR interface for scanned PDFs
//

import SwiftUI
import PDFKit
import Vision

struct OCRView: View {
    @EnvironmentObject var documentManager: DocumentManager
    @StateObject private var ocrManager = OCRManager.shared
    @State private var selectedLanguages: Set<String> = ["en-US"]
    @State private var showLanguagePicker = false
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            Divider()
            
            if ocrManager.isProcessing {
                processingView
            } else if !ocrManager.currentPageText.isEmpty || !ocrManager.ocrResults.isEmpty {
                resultsView
            } else {
                emptyState
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("OCR Text")
                    .font(.headline)
                
                Spacer()
                
                Menu {
                    Button("Current Page") {
                        performOCRCurrentPage()
                    }
                    
                    Button("All Pages") {
                        performOCRAllPages()
                    }
                    
                    Divider()
                    
                    Button("Settings...") {
                        showLanguagePicker = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "text.viewfinder")
                        Text("Scan")
                    }
                    .font(.caption)
                }
                .menuStyle(.borderedButton)
                .disabled(documentManager.pdfDocument == nil || ocrManager.isProcessing)
            }
            
            // Recognition level toggle
            HStack {
                Text("Accuracy:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("", selection: $ocrManager.recognitionLevel) {
                    Text("Fast").tag(VNRequestTextRecognitionLevel.fast)
                    Text("Accurate").tag(VNRequestTextRecognitionLevel.accurate)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
        }
        .padding()
    }
    
    private var processingView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ProgressView(value: ocrManager.progress) {
                Text("Scanning page...")
                    .font(.caption)
            }
            .progressViewStyle(.linear)
            .padding(.horizontal, 40)
            
            Text("\(Int(ocrManager.progress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No OCR Text")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Scan a page to extract text\nfrom scanned images")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
    }
    
    private var resultsView: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search OCR text...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.systemBackground)
            )
            .padding()
            
            // Text content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !ocrManager.currentPageText.isEmpty {
                        OCRPageSection(
                            pageIndex: documentManager.currentPageIndex,
                            text: ocrManager.currentPageText,
                            searchText: searchText
                        )
                    }
                    
                    // Other pages
                    ForEach(ocrManager.ocrResults.keys.sorted(), id: \.self) { pageIndex in
                        if pageIndex != documentManager.currentPageIndex,
                           let results = ocrManager.ocrResults[pageIndex] {
                            OCRPageSection(
                                pageIndex: pageIndex,
                                text: results.map { $0.text }.joined(separator: "\n"),
                                searchText: searchText
                            )
                        }
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Export options
            HStack {
                Button(action: copyText) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                    }
                }
                
                Button(action: exportText) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export")
                    }
                }
            }
            .font(.caption)
            .padding()
        }
        .sheet(isPresented: $showLanguagePicker) {
            OCRLanguageSettings(selectedLanguages: $selectedLanguages)
        }
    }
    
    // MARK: - Actions
    
    private func performOCRCurrentPage() {
        guard let page = documentManager.pdfDocument?.page(at: documentManager.currentPageIndex) else { return }
        
        Task {
            _ = await ocrManager.performOCROnCurrentPage(page, pageIndex: documentManager.currentPageIndex)
        }
    }
    
    private func performOCRAllPages() {
        guard let document = documentManager.pdfDocument else { return }
        
        Task {
            await ocrManager.performOCR(on: document)
        }
    }
    
    private func copyText() {
        let text = ocrManager.currentPageText.isEmpty
            ? ocrManager.ocrResults.values.flatMap { $0 }.map { $0.text }.joined(separator: "\n")
            : ocrManager.currentPageText
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    
    private func exportText() {
        guard let document = documentManager.pdfDocument else { return }
        ocrManager.exportOCRText(for: document)
    }
}

struct OCRPageSection: View {
    let pageIndex: Int
    let text: String
    let searchText: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Page \(pageIndex + 1)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            
            Text(highlightedText)
                .font(.system(size: 12))
                .textSelection(.enabled)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.systemBackground)
                )
        }
    }
    
    private var highlightedText: AttributedString {
        var attributedString = AttributedString(text)
        
        if !searchText.isEmpty {
            let lowercaseText = text.lowercased()
            let lowercaseSearch = searchText.lowercased()
            
            var searchStartIndex = lowercaseText.startIndex
            while let range = lowercaseText.range(of: lowercaseSearch, range: searchStartIndex..<lowercaseText.endIndex) {
                let start = text.distance(from: text.startIndex, to: range.lowerBound)
                let length = searchText.count
                
                if let attrRange = Range<AttributedString.Index>(
                    NSRange(location: start, length: length),
                    in: attributedString
                ) {
                    attributedString[attrRange].backgroundColor = .yellow
                }
                
                searchStartIndex = range.upperBound
            }
        }
        
        return attributedString
    }
}

struct OCRLanguageSettings: View {
    @Binding var selectedLanguages: Set<String>
    @Environment(\.dismiss) private var dismiss
    @StateObject private var ocrManager = OCRManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            Text("OCR Languages")
                .font(.headline)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(OCRManager.supportedLanguages, id: \.self) { language in
                        Toggle(isOn: Binding(
                            get: { selectedLanguages.contains(language) },
                            set: { isSelected in
                                if isSelected {
                                    selectedLanguages.insert(language)
                                } else {
                                    selectedLanguages.remove(language)
                                }
                            }
                        )) {
                            Text(languageDisplayName(language))
                        }
                    }
                }
                .padding()
            }
            .frame(height: 200)
            
            Toggle("Use language correction", isOn: $ocrManager.usesLanguageCorrection)
                .padding(.horizontal)
            
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                
                Button("Apply") {
                    ocrManager.recognitionLanguages = Array(selectedLanguages)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 300)
    }
    
    private func languageDisplayName(_ code: String) -> String {
        let locale = Locale(identifier: code)
        return locale.localizedString(forIdentifier: code) ?? code
    }
}
