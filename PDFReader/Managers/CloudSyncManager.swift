//
//  CloudSyncManager.swift
//  PDFReader
//
//  iCloud and cloud storage sync support
//

import Foundation
import AppKit

enum CloudProvider: String, CaseIterable, Identifiable {
    case icloud = "iCloud"
    case local = "Local"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .icloud: return "icloud"
        case .local: return "folder"
        }
    }
}

class CloudSyncManager: ObservableObject {
    static let shared = CloudSyncManager()
    
    @Published var isICloudAvailable = false
    @Published var isSyncing = false
    @Published var syncProgress: Double = 0
    @Published var lastSyncDate: Date?
    @Published var syncedDocuments: [URL] = []
    @Published var errorMessage: String?
    
    private var iCloudContainerURL: URL?
    private let fileManager = FileManager.default
    
    private init() {
        checkICloudAvailability()
    }
    
    // MARK: - iCloud Availability
    
    func checkICloudAvailability() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)
            
            DispatchQueue.main.async {
                self?.isICloudAvailable = containerURL != nil
                self?.iCloudContainerURL = containerURL
                
                if containerURL != nil {
                    self?.createDocumentsDirectory()
                    self?.loadSyncedDocuments()
                }
            }
        }
    }
    
    private func createDocumentsDirectory() {
        guard let containerURL = iCloudContainerURL else { return }
        
        let documentsURL = containerURL.appendingPathComponent("Documents")
        
        if !fileManager.fileExists(atPath: documentsURL.path) {
            try? fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Sync Operations
    
    func syncDocument(at url: URL) async throws {
        guard isICloudAvailable, let containerURL = iCloudContainerURL else {
            throw CloudSyncError.iCloudNotAvailable
        }
        
        await MainActor.run {
            isSyncing = true
            syncProgress = 0
        }
        
        do {
            let documentsURL = containerURL.appendingPathComponent("Documents")
            let destinationURL = documentsURL.appendingPathComponent(url.lastPathComponent)
            
            // Check if file already exists in iCloud
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            
            // Copy file to iCloud
            try fileManager.copyItem(at: url, to: destinationURL)
            
            // Wait for upload to complete
            try await waitForUpload(destinationURL)
            
            await MainActor.run {
                isSyncing = false
                syncProgress = 1.0
                lastSyncDate = Date()
                loadSyncedDocuments()
            }
        } catch {
            await MainActor.run {
                isSyncing = false
                errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    private func waitForUpload(_ url: URL) async throws {
        var attempts = 0
        let maxAttempts = 60 // 60 seconds timeout
        
        while attempts < maxAttempts {
            var isUploaded: AnyObject?
            try (url as NSURL).getResourceValue(&isUploaded, forKey: .ubiquitousItemIsUploadedKey)
            
            if let uploaded = isUploaded as? Bool, uploaded {
                return
            }
            
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            attempts += 1
            
            await MainActor.run {
                syncProgress = Double(attempts) / Double(maxAttempts)
            }
        }
        
        throw CloudSyncError.uploadTimeout
    }
    
    func downloadDocument(_ cloudURL: URL, to localURL: URL) async throws {
        guard isICloudAvailable else {
            throw CloudSyncError.iCloudNotAvailable
        }
        
        await MainActor.run {
            isSyncing = true
            syncProgress = 0
        }
        
        do {
            // Start downloading
            try fileManager.startDownloadingUbiquitousItem(at: cloudURL)
            
            // Wait for download
            try await waitForDownload(cloudURL)
            
            // Copy to local
            if fileManager.fileExists(atPath: localURL.path) {
                try fileManager.removeItem(at: localURL)
            }
            try fileManager.copyItem(at: cloudURL, to: localURL)
            
            await MainActor.run {
                isSyncing = false
                syncProgress = 1.0
            }
        } catch {
            await MainActor.run {
                isSyncing = false
                errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    private func waitForDownload(_ url: URL) async throws {
        var attempts = 0
        let maxAttempts = 60
        
        while attempts < maxAttempts {
            var isDownloaded: AnyObject?
            try (url as NSURL).getResourceValue(&isDownloaded, forKey: .ubiquitousItemDownloadingStatusKey)
            
            if let status = isDownloaded as? String, status == URLUbiquitousItemDownloadingStatus.current.rawValue {
                return
            }
            
            try await Task.sleep(nanoseconds: 1_000_000_000)
            attempts += 1
            
            await MainActor.run {
                syncProgress = Double(attempts) / Double(maxAttempts)
            }
        }
        
        throw CloudSyncError.downloadTimeout
    }
    
    func loadSyncedDocuments() {
        guard let containerURL = iCloudContainerURL else { return }
        
        let documentsURL = containerURL.appendingPathComponent("Documents")
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: documentsURL,
                includingPropertiesForKeys: [.nameKey, .contentModificationDateKey],
                options: .skipsHiddenFiles
            )
            
            syncedDocuments = contents.filter { $0.pathExtension.lowercased() == "pdf" }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func deleteFromCloud(_ url: URL) throws {
        guard isICloudAvailable else {
            throw CloudSyncError.iCloudNotAvailable
        }
        
        try fileManager.removeItem(at: url)
        loadSyncedDocuments()
    }
    
    // MARK: - Bookmarks & Settings Sync
    
    func syncBookmarks(_ bookmarks: Data) async throws {
        guard let containerURL = iCloudContainerURL else {
            throw CloudSyncError.iCloudNotAvailable
        }
        
        let bookmarksURL = containerURL.appendingPathComponent("bookmarks.json")
        try bookmarks.write(to: bookmarksURL)
    }
    
    func loadSyncedBookmarks() async throws -> Data? {
        guard let containerURL = iCloudContainerURL else { return nil }
        
        let bookmarksURL = containerURL.appendingPathComponent("bookmarks.json")
        
        guard fileManager.fileExists(atPath: bookmarksURL.path) else { return nil }
        
        try fileManager.startDownloadingUbiquitousItem(at: bookmarksURL)
        try await waitForDownload(bookmarksURL)
        
        return try Data(contentsOf: bookmarksURL)
    }
    
    func syncReadingProgress(_ progress: Data) async throws {
        guard let containerURL = iCloudContainerURL else {
            throw CloudSyncError.iCloudNotAvailable
        }
        
        let progressURL = containerURL.appendingPathComponent("reading_progress.json")
        try progress.write(to: progressURL)
    }
}

enum CloudSyncError: LocalizedError {
    case iCloudNotAvailable
    case uploadTimeout
    case downloadTimeout
    case fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .iCloudNotAvailable:
            return "iCloud is not available. Please sign in to iCloud in System Settings."
        case .uploadTimeout:
            return "Upload timed out. Please check your internet connection."
        case .downloadTimeout:
            return "Download timed out. Please check your internet connection."
        case .fileNotFound:
            return "File not found in iCloud."
        }
    }
}
