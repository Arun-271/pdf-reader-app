//
//  SearchBarView.swift
//  PDFReader
//
//  Search bar for finding text in PDF documents
//

import SwiftUI

struct SearchBarView: View {
    @EnvironmentObject var documentManager: DocumentManager
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search in document...", text: $documentManager.searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFieldFocused)
                    .onSubmit {
                        documentManager.performSearch()
                    }
                
                if !documentManager.searchText.isEmpty {
                    Button(action: { documentManager.clearSearch() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(8)
            .background(Color.systemBackground)
            .cornerRadius(8)
            .frame(maxWidth: 300)
            
            // Search button
            Button("Search") {
                documentManager.performSearch()
            }
            .buttonStyle(.bordered)
            
            // Results navigation
            if !documentManager.searchResults.isEmpty {
                HStack(spacing: 8) {
                    Text("\(documentManager.currentSearchIndex + 1) of \(documentManager.searchResults.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: { documentManager.previousSearchResult() }) {
                        Image(systemName: "chevron.up")
                    }
                    .buttonStyle(.borderless)
                    .help("Previous Result")
                    
                    Button(action: { documentManager.nextSearchResult() }) {
                        Image(systemName: "chevron.down")
                    }
                    .buttonStyle(.borderless)
                    .help("Next Result")
                }
            } else if !documentManager.searchText.isEmpty {
                Text("No results")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Close button
            Button(action: { documentManager.toggleSearch() }) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("Close Search")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.secondarySystemBackground)
        .onAppear {
            isSearchFieldFocused = true
        }
    }
}

struct SearchBarView_Previews: PreviewProvider {
    static var previews: some View {
        SearchBarView()
            .environmentObject(DocumentManager())
    }
}
