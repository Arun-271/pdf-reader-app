//
//  RecentDocumentsView.swift
//  PDFReader
//
//  View for displaying and managing recent documents
//

import SwiftUI
import AppKit

struct RecentDocumentsView: View {
    @EnvironmentObject var documentManager: DocumentManager
    @EnvironmentObject var recentDocumentsManager: RecentDocumentsManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Recent Documents")
                    .font(.headline)
                Spacer()
                
                if !recentDocumentsManager.recentDocuments.isEmpty {
                    Button("Clear All") {
                        recentDocumentsManager.clearAll()
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding()
            
            Divider()
            
            if recentDocumentsManager.recentDocuments.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("No Recent Documents")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("Documents you open will appear here")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(recentDocumentsManager.recentDocuments) { document in
                        RecentDocumentRow(document: document)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                openDocument(document)
                            }
                    }
                    .onDelete { offsets in
                        recentDocumentsManager.removeDocument(at: offsets)
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 500, height: 400)
    }
    
    private func openDocument(_ document: RecentDocument) {
        // Try security-scoped bookmark first
        if document.startAccess() {
            if let resolvedURL = document.resolvedURL() {
                documentManager.loadDocument(from: resolvedURL)
                if document.lastPageIndex > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        documentManager.goToPage(document.lastPageIndex)
                    }
                }
                dismiss()
                return
            }
        }
        
        // Try direct URL access (for files in accessible locations)
        if FileManager.default.fileExists(atPath: document.url.path) {
            documentManager.loadDocument(from: document.url)
            if document.lastPageIndex > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    documentManager.goToPage(document.lastPageIndex)
                }
            }
            dismiss()
            return
        }
        
        // Fallback: Show file picker to re-grant access
        showFilePickerForDocument(document)
    }
    
    private func showFilePickerForDocument(_ document: RecentDocument) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.pdf]
        panel.message = "Please re-select the file: \(document.fileName)"
        panel.directoryURL = document.url.deletingLastPathComponent()
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                documentManager.loadDocument(from: url)
                // Update the bookmark for this document
                recentDocumentsManager.addDocument(
                    url: url,
                    pageCount: document.pageCount,
                    currentPage: document.lastPageIndex
                )
                dismiss()
            }
        }
    }
}

struct RecentDocumentRow: View {
    let document: RecentDocument
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // PDF icon
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 40, height: 50)
                
                Image(systemName: "doc.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.red)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(document.fileName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text("\(document.pageCount) pages")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("Last page: \(document.lastPageIndex + 1)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(document.url.deletingLastPathComponent().path)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatDate(document.lastOpened))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if isHovered {
                    Button(action: { showInFinder() }) {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.borderless)
                    .help("Show in Finder")
                }
            }
        }
        .padding(.vertical, 8)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func showInFinder() {
        NSWorkspace.shared.selectFile(document.url.path, inFileViewerRootedAtPath: "")
    }
}

struct RecentDocumentsView_Previews: PreviewProvider {
    static var previews: some View {
        RecentDocumentsView()
            .environmentObject(DocumentManager())
            .environmentObject(RecentDocumentsManager())
    }
}
