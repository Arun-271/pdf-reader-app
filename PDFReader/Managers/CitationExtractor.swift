//
//  CitationExtractor.swift
//  PDFReader
//
//  Extracts and formats citations from PDF documents
//

import Foundation
import PDFKit
import NaturalLanguage

enum CitationFormat: String, CaseIterable, Identifiable {
    case apa = "APA"
    case mla = "MLA"
    case chicago = "Chicago"
    case bibtex = "BibTeX"
    case harvard = "Harvard"
    
    var id: String { rawValue }
}

struct ExtractedCitation: Identifiable, Hashable {
    let id = UUID()
    var rawText: String
    var authors: [String]
    var title: String
    var year: String?
    var journal: String?
    var volume: String?
    var pages: String?
    var doi: String?
    var url: String?
    var publisher: String?
    var pageIndex: Int? // Page where citation was found
    var pageLabel: String? // Page label for display
    
    func formatted(as format: CitationFormat) -> String {
        switch format {
        case .apa:
            return formatAPA()
        case .mla:
            return formatMLA()
        case .chicago:
            return formatChicago()
        case .bibtex:
            return formatBibTeX()
        case .harvard:
            return formatHarvard()
        }
    }
    
    private func formatAPA() -> String {
        var citation = ""
        
        // Authors
        if !authors.isEmpty {
            citation += authors.joined(separator: ", ")
        }
        
        // Year
        if let year = year {
            citation += " (\(year))."
        }
        
        // Title
        if !title.isEmpty {
            citation += " \(title)."
        }
        
        // Journal
        if let journal = journal {
            citation += " *\(journal)*"
            if let volume = volume {
                citation += ", \(volume)"
            }
            if let pages = pages {
                citation += ", \(pages)"
            }
            citation += "."
        }
        
        // DOI
        if let doi = doi {
            citation += " https://doi.org/\(doi)"
        }
        
        return citation.trimmingCharacters(in: .whitespaces)
    }
    
    private func formatMLA() -> String {
        var citation = ""
        
        // Authors (Last, First format for MLA)
        if !authors.isEmpty {
            citation += authors.joined(separator: ", ")
        }
        
        // Title in quotes
        if !title.isEmpty {
            citation += " \"\(title).\""
        }
        
        // Journal in italics
        if let journal = journal {
            citation += " *\(journal)*,"
            if let volume = volume {
                citation += " vol. \(volume),"
            }
            if let year = year {
                citation += " \(year),"
            }
            if let pages = pages {
                citation += " pp. \(pages)"
            }
            citation += "."
        }
        
        return citation.trimmingCharacters(in: .whitespaces)
    }
    
    private func formatChicago() -> String {
        var citation = ""
        
        // Authors
        if !authors.isEmpty {
            citation += authors.joined(separator: ", ")
        }
        
        // Title in quotes
        if !title.isEmpty {
            citation += " \"\(title).\""
        }
        
        // Journal
        if let journal = journal {
            citation += " *\(journal)*"
            if let volume = volume {
                citation += " \(volume)"
            }
            if let year = year {
                citation += " (\(year))"
            }
            if let pages = pages {
                citation += ": \(pages)"
            }
            citation += "."
        }
        
        return citation.trimmingCharacters(in: .whitespaces)
    }
    
    private func formatBibTeX() -> String {
        let key = generateBibTeXKey()
        var bibtex = "@article{\(key),\n"
        
        if !authors.isEmpty {
            bibtex += "  author = {\(authors.joined(separator: " and "))},\n"
        }
        if !title.isEmpty {
            bibtex += "  title = {\(title)},\n"
        }
        if let journal = journal {
            bibtex += "  journal = {\(journal)},\n"
        }
        if let year = year {
            bibtex += "  year = {\(year)},\n"
        }
        if let volume = volume {
            bibtex += "  volume = {\(volume)},\n"
        }
        if let pages = pages {
            bibtex += "  pages = {\(pages)},\n"
        }
        if let doi = doi {
            bibtex += "  doi = {\(doi)},\n"
        }
        
        bibtex += "}"
        return bibtex
    }
    
    private func formatHarvard() -> String {
        var citation = ""
        
        // Authors
        if !authors.isEmpty {
            citation += authors.joined(separator: ", ")
        }
        
        // Year
        if let year = year {
            citation += " (\(year))"
        }
        
        // Title
        if !title.isEmpty {
            citation += " '\(title)',"
        }
        
        // Journal
        if let journal = journal {
            citation += " *\(journal)*"
            if let volume = volume {
                citation += ", \(volume)"
            }
            if let pages = pages {
                citation += ", pp. \(pages)"
            }
            citation += "."
        }
        
        return citation.trimmingCharacters(in: .whitespaces)
    }
    
    private func generateBibTeXKey() -> String {
        let authorKey = authors.first?.components(separatedBy: " ").last?.lowercased() ?? "unknown"
        let yearKey = year ?? "0000"
        let titleWord = title.components(separatedBy: " ").first?.lowercased() ?? "untitled"
        return "\(authorKey)\(yearKey)\(titleWord)"
    }
}

class CitationExtractor: ObservableObject {
    static let shared = CitationExtractor()
    
    @Published var extractedCitations: [ExtractedCitation] = []
    @Published var isExtracting = false
    @Published var progress: Double = 0
    
    private init() {}
    
    // MARK: - Extraction
    
    func extractCitations(from document: PDFDocument) async {
        await MainActor.run {
            isExtracting = true
            extractedCitations = []
            progress = 0
        }
        
        let totalPages = document.pageCount
        var allCitations: [ExtractedCitation] = []
        var foundReferencesSection = false
        var referencesStartPage = -1
        
        // First pass: Find references section and extract citations from it
        for i in 0..<totalPages {
            guard let page = document.page(at: i),
                  let text = page.string else { continue }
            
            await MainActor.run {
                progress = Double(i + 1) / Double(totalPages) * 0.5
            }
            
            let lowercaseText = text.lowercased()
            
            // Check if this page starts a references section
            if !foundReferencesSection {
                let referencePatterns = [
                    "references", "bibliography", "works cited", 
                    "literature cited", "citations", "sources"
                ]
                
                for pattern in referencePatterns {
                    // Look for section headers (usually on their own line or with numbers)
                    let headerPatterns = [
                        "\\n\\s*\(pattern)\\s*\\n",
                        "^\\s*\(pattern)\\s*$",
                        "\\d+\\.?\\s+\(pattern)",
                        "\(pattern)\\s*\\n"
                    ]
                    
                    for headerPattern in headerPatterns {
                        if lowercaseText.range(of: headerPattern, options: .regularExpression) != nil {
                            foundReferencesSection = true
                            referencesStartPage = i
                            break
                        }
                    }
                    if foundReferencesSection { break }
                }
            }
            
            // If we found references section, extract from this page onwards
            if foundReferencesSection && i >= referencesStartPage {
                let pageLabel = page.label ?? "Page \(i + 1)"
                let pageCitations = parseCitations(from: text, pageIndex: i, pageLabel: pageLabel)
                allCitations.append(contentsOf: pageCitations)
            }
        }
        
        // Second pass: If we found few or no citations, scan ALL pages for citation patterns
        if allCitations.count < 5 {
            await MainActor.run {
                progress = 0.5
            }
            
            for i in 0..<totalPages {
                guard let page = document.page(at: i),
                      let text = page.string else { continue }
                
                await MainActor.run {
                    progress = 0.5 + Double(i + 1) / Double(totalPages) * 0.4
                }
                
                let pageLabel = page.label ?? "Page \(i + 1)"
                let pageCitations = extractInlineCitations(from: text, pageIndex: i, pageLabel: pageLabel)
                
                // Only add if not already found
                for citation in pageCitations {
                    if !allCitations.contains(where: { $0.rawText == citation.rawText }) {
                        allCitations.append(citation)
                    }
                }
            }
        }
        
        // Sort by page index
        allCitations.sort { ($0.pageIndex ?? 0) < ($1.pageIndex ?? 0) }
        
        // Remove duplicates based on title/URL similarity
        var uniqueCitations: [ExtractedCitation] = []
        for citation in allCitations {
            let isDuplicate = uniqueCitations.contains { existing in
                if !citation.title.isEmpty && !existing.title.isEmpty {
                    return citation.title.lowercased() == existing.title.lowercased()
                }
                if let url1 = citation.url, let url2 = existing.url, !url1.isEmpty && !url2.isEmpty {
                    return url1 == url2
                }
                return false
            }
            if !isDuplicate {
                uniqueCitations.append(citation)
            }
        }
        
        await MainActor.run {
            extractedCitations = uniqueCitations
            isExtracting = false
            progress = 1.0
        }
    }
    
    // Extract inline citations like [1], (Author, 2020), etc.
    private func extractInlineCitations(from text: String, pageIndex: Int, pageLabel: String?) -> [ExtractedCitation] {
        var citations: [ExtractedCitation] = []
        
        // Pattern for numbered references: [1] or (1) followed by text
        let numberedRefPattern = #"[\[\(](\d+)[\]\)]\s+([A-Z][^.]+\..*?)(?=[\[\(]\d+[\]\)]|$)"#
        if let regex = try? NSRegularExpression(pattern: numberedRefPattern, options: [.dotMatchesLineSeparators]) {
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, options: [], range: range)
            
            for match in matches {
                if let citationRange = Range(match.range(at: 2), in: text) {
                    let citationText = String(text[citationRange])
                    if var citation = parseSingleCitation(citationText) {
                        citation.pageIndex = pageIndex
                        citation.pageLabel = pageLabel
                        citations.append(citation)
                    }
                }
            }
        }
        
        // Pattern for URL citations
        let urlPattern = #"(?:https?://[^\s\])\n]+)"#
        if let regex = try? NSRegularExpression(pattern: urlPattern, options: []) {
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, options: [], range: range)
            
            for match in matches {
                if let urlRange = Range(match.range, in: text) {
                    let url = String(text[urlRange])
                    // Check if this URL is likely a citation (not just any link)
                    if url.contains("doi.org") || url.contains("arxiv") || url.contains("scholar") ||
                       url.contains("researchgate") || url.contains("ieee") || url.contains("acm.org") {
                        var citation = ExtractedCitation(rawText: url, authors: [], title: url)
                        citation.url = url
                        citation.pageIndex = pageIndex
                        citation.pageLabel = pageLabel
                        citations.append(citation)
                    }
                }
            }
        }
        
        return citations
    }
    
    private func parseCitations(from text: String, pageIndex: Int = 0, pageLabel: String? = nil) -> [ExtractedCitation] {
        var citations: [ExtractedCitation] = []
        
        // Split by common citation patterns
        let lines = text.components(separatedBy: .newlines)
        var currentCitation = ""
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Check if this looks like a new citation (starts with author name pattern or number)
            if isNewCitation(trimmed) && !currentCitation.isEmpty {
                if var citation = parseSingleCitation(currentCitation) {
                    citation.pageIndex = pageIndex
                    citation.pageLabel = pageLabel
                    citations.append(citation)
                }
                currentCitation = trimmed
            } else {
                currentCitation += " " + trimmed
            }
        }
        
        // Don't forget the last citation
        if !currentCitation.isEmpty {
            if var citation = parseSingleCitation(currentCitation) {
                citation.pageIndex = pageIndex
                citation.pageLabel = pageLabel
                citations.append(citation)
            }
        }
        
        return citations
    }
    
    private func isNewCitation(_ text: String) -> Bool {
        // Check for numbered citation [1], 1., (1), [1]
        let numberedPattern = #"^\s*[\[\(]?\d+[\]\)\.\]]"#
        if text.range(of: numberedPattern, options: .regularExpression) != nil {
            return true
        }
        
        // Check for author name pattern (Lastname, F. or LASTNAME)
        let authorPattern = #"^[A-Z][a-z]+,\s*[A-Z]\."#
        if text.range(of: authorPattern, options: .regularExpression) != nil {
            return true
        }
        
        return false
    }
    
    private func parseSingleCitation(_ text: String) -> ExtractedCitation? {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanText.count > 10 else { return nil }
        
        var citation = ExtractedCitation(
            rawText: cleanText,
            authors: [],
            title: ""
        )
        
        // Handle URL-based citations like "[1] Title: https://url"
        let urlCitationPattern = #"^\s*[\[\(]?(\d+)[\]\)\.\]]?\s+(.+?):\s*(https?://[^\s]+)"#
        if let match = cleanText.range(of: urlCitationPattern, options: .regularExpression) {
            let matched = String(cleanText[match])
            // Extract title (text before URL)
            if let colonRange = matched.range(of: ":") {
                let beforeColon = String(matched[matched.startIndex..<colonRange.lowerBound])
                // Remove the number prefix
                let titlePattern = #"[\[\(]?\d+[\]\)\.\]]?\s+(.+)$"#
                if let titleMatch = beforeColon.range(of: titlePattern, options: .regularExpression) {
                    var title = String(beforeColon[titleMatch])
                    // Clean up the number prefix
                    title = title.replacingOccurrences(of: #"^[\[\(]?\d+[\]\)\.\]]?\s+"#, with: "", options: .regularExpression)
                    citation.title = title.trimmingCharacters(in: .whitespaces)
                }
            }
            // Extract URL
            let urlPattern = #"https?://[^\s]+"#
            if let urlMatch = cleanText.range(of: urlPattern, options: .regularExpression) {
                citation.url = String(cleanText[urlMatch])
            }
            return citation
        }
        
        // Handle simple numbered citations like "[1] Title text"
        let simpleNumberedPattern = #"^\s*[\[\(]?(\d+)[\]\)\.\]]?\s+(.+)$"#
        if let match = cleanText.range(of: simpleNumberedPattern, options: .regularExpression) {
            let afterNumber = cleanText.replacingOccurrences(of: #"^\s*[\[\(]?\d+[\]\)\.\]]?\s+"#, with: "", options: .regularExpression)
            // Extract URL if present
            let urlPattern = #"https?://[^\s]+"#
            if let urlMatch = afterNumber.range(of: urlPattern, options: .regularExpression) {
                citation.url = String(afterNumber[urlMatch])
                // Title is text before URL
                let beforeUrl = String(afterNumber[..<urlMatch.lowerBound]).trimmingCharacters(in: .whitespaces)
                citation.title = beforeUrl.isEmpty ? String(afterNumber[urlMatch]) : beforeUrl
            } else {
                citation.title = afterNumber.trimmingCharacters(in: .whitespaces)
            }
        }
        
        // Extract year (4 digits, typically 19xx or 20xx)
        let yearPattern = #"\b(19|20)\d{2}\b"#
        if let yearMatch = cleanText.range(of: yearPattern, options: .regularExpression) {
            citation.year = String(cleanText[yearMatch])
        }
        
        // Extract DOI
        let doiPattern = #"10\.\d{4,}/[^\s]+"#
        if let doiMatch = cleanText.range(of: doiPattern, options: .regularExpression) {
            citation.doi = String(cleanText[doiMatch])
        }
        
        // Extract URL
        let urlPattern = #"https?://[^\s]+"#
        if let urlMatch = cleanText.range(of: urlPattern, options: .regularExpression) {
            citation.url = String(cleanText[urlMatch])
        }
        
        // Extract authors (text before year, typically)
        if let year = citation.year, let yearRange = cleanText.range(of: year) {
            let authorPart = String(cleanText[..<yearRange.lowerBound])
            citation.authors = parseAuthors(from: authorPart)
        }
        
        // Extract title (text in quotes or between year and journal)
        let quotedPattern = #""([^"]+)""#
        if let quoteMatch = cleanText.range(of: quotedPattern, options: .regularExpression) {
            var matched = String(cleanText[quoteMatch])
            matched = matched.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            citation.title = matched
        } else {
            // Try to extract title as text after year, before journal name
            citation.title = extractTitle(from: cleanText, year: citation.year)
        }
        
        // Extract volume/pages
        let volPattern = #"\b(\d+)\s*\((\d+)\)"#
        if let volMatch = cleanText.range(of: volPattern, options: .regularExpression) {
            let volString = String(cleanText[volMatch])
            citation.volume = volString
        }
        
        let pagesPattern = #"\bp+\.?\s*(\d+[-–]\d+)"#
        if let pagesMatch = cleanText.range(of: pagesPattern, options: .regularExpression) {
            citation.pages = String(cleanText[pagesMatch])
        }
        
        return citation
    }
    
    private func parseAuthors(from text: String) -> [String] {
        var authors: [String] = []
        
        // Clean the text
        var cleaned = text.replacingOccurrences(of: "&", with: ",")
        cleaned = cleaned.replacingOccurrences(of: " and ", with: ",")
        cleaned = cleaned.replacingOccurrences(of: "., ", with: ".,")
        
        // Split by comma or semicolon
        let parts = cleaned.components(separatedBy: CharacterSet(charactersIn: ",;"))
        
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && trimmed.count > 2 {
                authors.append(trimmed)
            }
        }
        
        return authors
    }
    
    private func extractTitle(from text: String, year: String?) -> String {
        guard let year = year, let yearRange = text.range(of: year) else {
            return ""
        }
        
        let afterYear = String(text[yearRange.upperBound...])
        let cleaned = afterYear.trimmingCharacters(in: CharacterSet(charactersIn: "().,:; "))
        
        // Take text until we hit a period followed by a capital letter (likely journal name)
        let sentencePattern = #"^([^.]+\.)"#
        if let sentenceMatch = cleaned.range(of: sentencePattern, options: .regularExpression) {
            return String(cleaned[sentenceMatch]).trimmingCharacters(in: .punctuationCharacters)
        }
        
        return String(cleaned.prefix(200))
    }
    
    // MARK: - Export
    
    func exportCitations(format: CitationFormat) -> String {
        return extractedCitations.map { $0.formatted(as: format) }.joined(separator: "\n\n")
    }
    
    func copyToClipboard(format: CitationFormat) {
        let text = exportCitations(format: format)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    
    func exportToFile(format: CitationFormat) {
        let text = exportCitations(format: format)
        
        let panel = NSSavePanel()
        panel.title = "Export Citations"
        panel.nameFieldStringValue = "citations.\(format == .bibtex ? "bib" : "txt")"
        panel.allowedContentTypes = [.plainText]
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? text.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}
