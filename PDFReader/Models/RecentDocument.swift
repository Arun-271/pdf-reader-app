//
//  RecentDocument.swift
//  PDFReader
//
//  Model for recently opened documents
//

import Foundation

struct RecentDocument: Identifiable, Codable, Equatable {
    let id: UUID
    var url: URL
    var fileName: String
    var lastOpened: Date
    var pageCount: Int
    var lastPageIndex: Int
    var bookmarkData: Data?  // Security-scoped bookmark for sandboxed access
    
    init(url: URL, pageCount: Int = 0, lastPageIndex: Int = 0) {
        self.id = UUID()
        self.url = url
        self.fileName = url.lastPathComponent
        self.lastOpened = Date()
        self.pageCount = pageCount
        self.lastPageIndex = lastPageIndex
        
        // Create security-scoped bookmark
        self.bookmarkData = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }
    
    // Resolve URL from bookmark data
    func resolvedURL() -> URL? {
        guard let bookmarkData = bookmarkData else { return url }
        
        var isStale = false
        guard let resolvedURL = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        
        return resolvedURL
    }
    
    // Start accessing security-scoped resource
    func startAccess() -> Bool {
        guard let resolvedURL = resolvedURL() else { return false }
        return resolvedURL.startAccessingSecurityScopedResource()
    }
    
    // Stop accessing security-scoped resource
    func stopAccess() {
        resolvedURL()?.stopAccessingSecurityScopedResource()
    }
}
