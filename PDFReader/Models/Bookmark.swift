//
//  Bookmark.swift
//  PDFReader
//
//  Bookmark model for saved PDF locations
//

import Foundation

struct Bookmark: Identifiable, Codable, Equatable {
    let id: UUID
    var pageIndex: Int
    var title: String
    var note: String
    var dateCreated: Date
    var color: BookmarkColor
    
    init(pageIndex: Int, title: String = "", note: String = "", color: BookmarkColor = .blue) {
        self.id = UUID()
        self.pageIndex = pageIndex
        self.title = title.isEmpty ? "Page \(pageIndex + 1)" : title
        self.note = note
        self.dateCreated = Date()
        self.color = color
    }
}

enum BookmarkColor: String, Codable, CaseIterable {
    case red, orange, yellow, green, blue, purple
    
    var color: String {
        switch self {
        case .red: return "red"
        case .orange: return "orange"
        case .yellow: return "yellow"
        case .green: return "green"
        case .blue: return "blue"
        case .purple: return "purple"
        }
    }
}
