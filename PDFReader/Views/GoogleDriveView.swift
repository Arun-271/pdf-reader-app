//
//  GoogleDriveView.swift
//  PDFReader
//
//  Google Drive file browser view
//

import SwiftUI
import PDFKit

struct GoogleDriveView: View {
    @EnvironmentObject var documentManager: DocumentManager
    @StateObject private var driveManager = GoogleDriveManager.shared
    @State private var selectedFile: GoogleDriveFile?
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Content
            switch driveManager.authState {
            case .signedOut:
                signInPrompt
            case .signingIn:
                signingInView
            case .signedIn:
                fileListView
            case .error(let message):
                errorView(message: message)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "externaldrive.fill.badge.icloud")
                .font(.title2)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Google Drive")
                    .font(.headline)
                
                if case .signedIn(let email) = driveManager.authState {
                    Text(email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if case .signedIn = driveManager.authState {
                Button(action: { driveManager.signOut() }) {
                    Text("Sign Out")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding()
    }
    
    // MARK: - Sign In Prompt
    private var signInPrompt: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "icloud.and.arrow.down")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                Text("Connect Google Drive")
                    .font(.headline)
                Text("Access your PDFs stored in Google Drive")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: { driveManager.signIn() }) {
                HStack {
                    Image(systemName: "person.badge.key")
                    Text("Sign in with Google")
                }
                .frame(maxWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Signing In View
    private var signingInView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Signing in...")
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    // MARK: - File List
    private var fileListView: some View {
        VStack(spacing: 0) {
            // Breadcrumb / Navigation
            if !driveManager.folderPath.isEmpty {
                HStack {
                    Button(action: { driveManager.navigateBack() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    
                    Spacer()
                    
                    Text(driveManager.folderPath.last ?? "My Drive")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.secondarySystemBackground)
            }
            
            // File list
            if driveManager.isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                    Text("Loading files...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Spacer()
                }
            } else if driveManager.files.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("No PDF files found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: { Task { await driveManager.listFiles() } }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(driveManager.files) { file in
                            DriveFileRow(
                                file: file,
                                isSelected: selectedFile?.id == file.id,
                                isDownloading: isDownloading && selectedFile?.id == file.id
                            ) {
                                handleFileTap(file)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            
            // Refresh button at bottom
            Divider()
            
            HStack {
                Button(action: { Task { await driveManager.listFiles(inFolder: driveManager.currentFolder) } }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .disabled(driveManager.isLoading)
                
                Spacer()
                
                Text("\(driveManager.files.filter { $0.isPDF }.count) PDFs")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
    
    // MARK: - Error View
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundColor(.orange)
            
            Text("Something went wrong")
                .font(.headline)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: { driveManager.signIn() }) {
                Text("Try Again")
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Helpers
    private func handleFileTap(_ file: GoogleDriveFile) {
        if file.mimeType == "application/vnd.google-apps.folder" {
            // Navigate into folder
            driveManager.navigateToFolder(file.id, folderName: file.name)
        } else if file.isPDF {
            // Download and open PDF
            selectedFile = file
            isDownloading = true
            
            Task {
                if let localURL = await driveManager.downloadFile(file) {
                    await MainActor.run {
                        documentManager.loadDocument(from: localURL)
                        isDownloading = false
                    }
                } else {
                    await MainActor.run {
                        isDownloading = false
                    }
                }
            }
        }
    }
}

// MARK: - File Row
struct DriveFileRow: View {
    let file: GoogleDriveFile
    let isSelected: Bool
    let isDownloading: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(iconBackgroundColor)
                        .frame(width: 32, height: 32)
                    
                    if isDownloading {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Image(systemName: iconName)
                            .font(.system(size: 14))
                            .foregroundColor(iconColor)
                    }
                }
                
                // File info
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        if let size = file.size, file.isPDF {
                            Text(file.formattedSize)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        if let date = file.modifiedDate {
                            Text(date, style: .date)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Chevron for folders
                if file.mimeType == "application/vnd.google-apps.folder" {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var iconName: String {
        if file.mimeType == "application/vnd.google-apps.folder" {
            return "folder.fill"
        } else {
            return "doc.fill"
        }
    }
    
    private var iconColor: Color {
        if file.mimeType == "application/vnd.google-apps.folder" {
            return .blue
        } else {
            return .red
        }
    }
    
    private var iconBackgroundColor: Color {
        if file.mimeType == "application/vnd.google-apps.folder" {
            return Color.blue.opacity(0.1)
        } else {
            return Color.red.opacity(0.1)
        }
    }
}

// MARK: - Preview
struct GoogleDriveView_Previews: PreviewProvider {
    static var previews: some View {
        GoogleDriveView()
            .environmentObject(DocumentManager())
            .frame(width: 350, height: 500)
    }
}
