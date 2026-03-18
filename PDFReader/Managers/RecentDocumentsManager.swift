//
//  RecentDocumentsManager.swift
//  PDFReader
//
//  Manages recently opened documents
//

import SwiftUI
import Combine

class RecentDocumentsManager: ObservableObject {
    @Published var recentDocuments: [RecentDocument] = []
    
    private let saveKey = "PDFReaderRecentDocuments"
    private let maxRecentDocuments = 20
    
    init() {
        loadRecentDocuments()
    }
    
    func addDocument(url: URL, pageCount: Int, currentPage: Int = 0) {
        // Remove existing entry for same URL
        recentDocuments.removeAll { $0.url == url }
        
        // Add new entry at the beginning
        let document = RecentDocument(url: url, pageCount: pageCount, lastPageIndex: currentPage)
        recentDocuments.insert(document, at: 0)
        
        // Trim to max size
        if recentDocuments.count > maxRecentDocuments {
            recentDocuments = Array(recentDocuments.prefix(maxRecentDocuments))
        }
        
        saveRecentDocuments()
    }
    
    func updateLastPage(for url: URL, pageIndex: Int) {
        if let index = recentDocuments.firstIndex(where: { $0.url == url }) {
            recentDocuments[index].lastPageIndex = pageIndex
            recentDocuments[index].lastOpened = Date()
            saveRecentDocuments()
        }
    }
    
    func removeDocument(at offsets: IndexSet) {
        recentDocuments.remove(atOffsets: offsets)
        saveRecentDocuments()
    }
    
    func clearAll() {
        recentDocuments.removeAll()
        saveRecentDocuments()
    }
    
    func documentExists(_ document: RecentDocument) -> Bool {
        return FileManager.default.fileExists(atPath: document.url.path)
    }
    
    private func saveRecentDocuments() {
        if let data = try? JSONEncoder().encode(recentDocuments) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }
    
    private func loadRecentDocuments() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([RecentDocument].self, from: data) {
            // Keep all documents - we'll verify access when opening
            // Don't filter here as sandbox prevents checking file existence
            recentDocuments = decoded
        }
    }
}
