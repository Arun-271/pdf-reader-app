//
//  DictionaryView.swift
//  PDFReader
//
//  Dictionary lookup view for selected words
//

import SwiftUI

struct DictionaryView: View {
    @EnvironmentObject var documentManager: DocumentManager
    @StateObject private var dictionaryManager = DictionaryManager()
    @State private var searchWord: String = ""
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Dictionary")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondarySystemBackground)
            
            Divider()
            
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Look up a word...", text: $searchWord)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit {
                        lookupWord()
                    }
                
                if !searchWord.isEmpty {
                    Button(action: { searchWord = ""; dictionaryManager.clear() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
                
                Button("Look up") {
                    lookupWord()
                }
                .buttonStyle(.bordered)
                .disabled(searchWord.isEmpty)
            }
            .padding(8)
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Selection hint
                    if searchWord.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "text.book.closed")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            
                            Text("Select text in the PDF to look up")
                                .foregroundColor(.secondary)
                            
                            Button("Use Current Selection") {
                                useSelection()
                            }
                            .buttonStyle(.bordered)
                            .disabled(documentManager.pdfView?.currentSelection == nil)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    }
                    
                    // Loading
                    if dictionaryManager.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding()
                    }
                    
                    // Error
                    if let error = dictionaryManager.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text(error)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                    
                    // Definition
                    if let definition = dictionaryManager.definition {
                        DefinitionCard(definition: definition)
                    }
                }
                .padding()
            }
        }
    }
    
    private func lookupWord() {
        Task {
            await dictionaryManager.lookupWord(searchWord)
        }
    }
    
    private func useSelection() {
        if let selection = documentManager.pdfView?.currentSelection,
           let text = selection.string {
            // Get first word if multiple words selected
            let word = text.components(separatedBy: .whitespaces).first ?? text
            searchWord = word.trimmingCharacters(in: .punctuationCharacters)
            lookupWord()
        }
    }
}

struct DefinitionCard: View {
    let definition: DictionaryManager.DictionaryDefinition
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Word header
            HStack(alignment: .bottom, spacing: 8) {
                Text(definition.word)
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let phonetic = definition.phonetic {
                    Text(phonetic)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Copy button
                Button(action: { copyToClipboard() }) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy definition")
            }
            
            // Part of speech
            if let pos = definition.partOfSpeech {
                Text(pos)
                    .font(.caption)
                    .italic()
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(4)
            }
            
            Divider()
            
            // Definitions
            ForEach(Array(definition.definitions.enumerated()), id: \.offset) { index, def in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    
                    Text(def)
                        .font(.body)
                }
            }
            
            // Examples
            if !definition.examples.isEmpty {
                Divider()
                
                Text("Examples")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                ForEach(definition.examples, id: \.self) { example in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "quote.opening")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(example)
                            .font(.callout)
                            .italic()
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color.secondarySystemBackground)
        .cornerRadius(8)
    }
    
    private func copyToClipboard() {
        let text = "\(definition.word): \(definition.definitions.joined(separator: "; "))"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

struct DictionaryView_Previews: PreviewProvider {
    static var previews: some View {
        DictionaryView()
            .environmentObject(DocumentManager())
            .frame(width: 300, height: 500)
    }
}
