//
//  CloudSyncView.swift
//  PDFReader
//
//  iCloud sync management UI
//

import SwiftUI

struct CloudSyncView: View {
    @EnvironmentObject var documentManager: DocumentManager
    @StateObject private var syncManager = CloudSyncManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            Divider()
            
            // Content
            ScrollView {
                VStack(spacing: 16) {
                    // Connection status
                    connectionStatusCard
                    
                    // Sync actions
                    if syncManager.isICloudAvailable {
                        syncActionsCard
                        
                        // Synced documents list
                        syncedDocumentsCard
                    }
                }
                .padding()
            }
        }
    }
    
    private var headerSection: some View {
        HStack {
            Image(systemName: "icloud")
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("iCloud Sync")
                .font(.headline)
            
            Spacer()
            
            if syncManager.isSyncing {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding()
    }
    
    private var connectionStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: syncManager.isICloudAvailable ? "checkmark.icloud.fill" : "xmark.icloud")
                    .font(.title2)
                    .foregroundColor(syncManager.isICloudAvailable ? .green : .red)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(syncManager.isICloudAvailable ? "Connected" : "Not Connected")
                        .font(.headline)
                    
                    Text(syncManager.isICloudAvailable ? "iCloud is available" : "Sign in to iCloud in System Settings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    syncManager.checkICloudAvailability()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Refresh status")
            }
            
            if let lastSync = syncManager.lastSyncDate {
                Text("Last synced: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    private var syncActionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sync Current Document")
                .font(.subheadline)
                .fontWeight(.medium)
            
            if documentManager.pdfDocument != nil, let fileURL = documentManager.fileURL {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(documentManager.fileName)
                            .font(.caption)
                            .lineLimit(1)
                        
                        Text("\(documentManager.pageCount) pages")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        Task {
                            try? await syncManager.syncDocument(at: fileURL)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "icloud.and.arrow.up")
                            Text("Upload")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(syncManager.isSyncing)
                }
                
                if syncManager.isSyncing {
                    ProgressView(value: syncManager.syncProgress)
                        .progressViewStyle(.linear)
                    
                    Text("Uploading... \(Int(syncManager.syncProgress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if let error = syncManager.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            } else {
                Text("Open a document to sync")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    private var syncedDocumentsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Cloud Documents")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(syncManager.syncedDocuments.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.1))
                    )
            }
            
            if syncManager.syncedDocuments.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.badge.plus")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("No documents synced yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ForEach(syncManager.syncedDocuments, id: \.absoluteString) { url in
                    CloudDocumentRow(url: url) {
                        openCloudDocument(url)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    private func openCloudDocument(_ url: URL) {
        Task {
            let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
            try? await syncManager.downloadDocument(url, to: localURL)
            
            await MainActor.run {
                documentManager.loadDocument(from: localURL)
            }
        }
    }
}

struct CloudDocumentRow: View {
    let url: URL
    let onOpen: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.fill")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .font(.caption)
                    .lineLimit(1)
                
                Text("iCloud")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onOpen) {
                Image(systemName: "icloud.and.arrow.down")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("Download and open")
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.blue.opacity(0.1) : Color.clear)
        )
        .onHover { isHovered = $0 }
    }
}
