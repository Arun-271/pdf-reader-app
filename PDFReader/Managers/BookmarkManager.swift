//
//  BookmarkManager.swift
//  PDFReader
//
//  Manages bookmarks for PDF documents
//

import SwiftUI
import Combine

class BookmarkManager: ObservableObject {
    @Published var bookmarks: [String: [Bookmark]] = [:] // keyed by document name
    
    private let saveKey = "PDFReaderBookmarks"
    
    init() {
        loadBookmarks()
    }
    
    func bookmarks(for documentName: String) -> [Bookmark] {
        return bookmarks[documentName] ?? []
    }
    
    func addBookmark(for documentName: String, pageIndex: Int, title: String = "", note: String = "", color: BookmarkColor = .blue) {
        var docBookmarks = bookmarks[documentName] ?? []
        
        // Check if bookmark already exists for this page
        if !docBookmarks.contains(where: { $0.pageIndex == pageIndex }) {
            let bookmark = Bookmark(pageIndex: pageIndex, title: title, note: note, color: color)
            docBookmarks.append(bookmark)
            docBookmarks.sort { $0.pageIndex < $1.pageIndex }
            bookmarks[documentName] = docBookmarks
            saveBookmarks()
        }
    }
    
    func removeBookmark(for documentName: String, at pageIndex: Int) {
        var docBookmarks = bookmarks[documentName] ?? []
        docBookmarks.removeAll { $0.pageIndex == pageIndex }
        bookmarks[documentName] = docBookmarks
        saveBookmarks()
    }
    
    func removeBookmark(for documentName: String, bookmark: Bookmark) {
        var docBookmarks = bookmarks[documentName] ?? []
        docBookmarks.removeAll { $0.id == bookmark.id }
        bookmarks[documentName] = docBookmarks
        saveBookmarks()
    }
    
    func updateBookmark(for documentName: String, bookmark: Bookmark) {
        var docBookmarks = bookmarks[documentName] ?? []
        if let index = docBookmarks.firstIndex(where: { $0.id == bookmark.id }) {
            docBookmarks[index] = bookmark
            bookmarks[documentName] = docBookmarks
            saveBookmarks()
        }
    }
    
    func isBookmarked(documentName: String, pageIndex: Int) -> Bool {
        return bookmarks[documentName]?.contains(where: { $0.pageIndex == pageIndex }) ?? false
    }
    
    func toggleBookmark(for documentName: String, pageIndex: Int) {
        if isBookmarked(documentName: documentName, pageIndex: pageIndex) {
            removeBookmark(for: documentName, at: pageIndex)
        } else {
            addBookmark(for: documentName, pageIndex: pageIndex)
        }
    }
    
    private func saveBookmarks() {
        if let data = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }
    
    private func loadBookmarks() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([String: [Bookmark]].self, from: data) {
            bookmarks = decoded
        }
    }
}
