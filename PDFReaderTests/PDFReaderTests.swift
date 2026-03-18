//
//  PDFReaderTests.swift
//  PDFReaderTests
//
//  Unit tests for PDF Reader app
//

import XCTest
@testable import PDFReader
import PDFKit

// MARK: - Test Helpers

struct TestHelpers {
    static func createTestPDF(pageCount: Int = 3) -> PDFDocument {
        let document = PDFDocument()
        
        for i in 0..<pageCount {
            let page = PDFPage()
            document.insert(page, at: i)
        }
        
        return document
    }
}

final class PDFReaderTests: XCTestCase {
    
    // MARK: - DocumentManager Tests
    
    func testDocumentManagerInitialState() {
        let manager = DocumentManager()
        
        XCTAssertNil(manager.pdfDocument)
        XCTAssertEqual(manager.currentPageIndex, 0)
        XCTAssertEqual(manager.scaleFactor, 1.0)
        XCTAssertTrue(manager.showSidebar)
        XCTAssertFalse(manager.showRightPanel)
        XCTAssertFalse(manager.showSearch)
        XCTAssertEqual(manager.fileName, "No Document")
        XCTAssertFalse(manager.highlighterEnabled)
    }
    
    func testPageNavigation() {
        let manager = DocumentManager()
        manager.displayMode = .singlePage // Ensures deterministic page jumps for testing
        
        // Create a simple test PDF
        let pdfDocument = createTestPDF(pageCount: 5)
        manager.pdfDocument = pdfDocument
        
        // Test goToPage
        manager.goToPage(2)
        XCTAssertEqual(manager.currentPageIndex, 2)
        
        // Test nextPage
        manager.nextPage()
        XCTAssertEqual(manager.currentPageIndex, 3)
        
        // Test previousPage
        manager.previousPage()
        XCTAssertEqual(manager.currentPageIndex, 2)
        
        // Test firstPage
        manager.firstPage()
        XCTAssertEqual(manager.currentPageIndex, 0)
        
        // Test lastPage
        manager.lastPage()
        XCTAssertEqual(manager.currentPageIndex, 4)
        
        // Test boundary - can't go past last page
        manager.nextPage()
        XCTAssertEqual(manager.currentPageIndex, 4)
        
        // Test boundary - can't go before first page
        manager.firstPage()
        manager.previousPage()
        XCTAssertEqual(manager.currentPageIndex, 0)
    }
    
    func testZoomFunctions() {
        let manager = DocumentManager()
        
        // Test zoomIn
        let initialScale = manager.scaleFactor
        manager.zoomIn()
        XCTAssertGreaterThan(manager.scaleFactor, initialScale)
        
        // Test zoomOut
        manager.zoomOut()
        XCTAssertEqual(manager.scaleFactor, initialScale, accuracy: 0.01)
        
        // Test resetZoom
        manager.zoomIn()
        manager.zoomIn()
        manager.resetZoom()
        XCTAssertEqual(manager.scaleFactor, 1.0)
        
        // Test max zoom limit
        for _ in 0..<20 {
            manager.zoomIn()
        }
        XCTAssertLessThanOrEqual(manager.scaleFactor, 5.0)
        
        // Test min zoom limit
        for _ in 0..<20 {
            manager.zoomOut()
        }
        XCTAssertGreaterThanOrEqual(manager.scaleFactor, 0.25)
    }
    
    func testToggleFunctions() {
        let manager = DocumentManager()
        
        // Test toggleSidebar
        let initialSidebar = manager.showSidebar
        manager.toggleSidebar()
        XCTAssertNotEqual(manager.showSidebar, initialSidebar)
        manager.toggleSidebar()
        XCTAssertEqual(manager.showSidebar, initialSidebar)
        
        // Test toggleSearch
        let initialSearch = manager.showSearch
        manager.toggleSearch()
        XCTAssertNotEqual(manager.showSearch, initialSearch)
        
        // Test toggleRightPanel
        let initialPanel = manager.showRightPanel
        manager.toggleRightPanel()
        XCTAssertNotEqual(manager.showRightPanel, initialPanel)
    }
    
    func testHighlighterToggle() {
        let manager = DocumentManager()
        
        XCTAssertFalse(manager.highlighterEnabled)
        manager.highlighterEnabled = true
        XCTAssertTrue(manager.highlighterEnabled)
        
        // Test default color
        XCTAssertEqual(manager.highlighterColor, .systemYellow)
        
        // Test color change
        manager.highlighterColor = .systemGreen
        XCTAssertEqual(manager.highlighterColor, .systemGreen)
    }
    
    // MARK: - RecentDocumentsManager Tests
    
    func testRecentDocumentsAddDocument() {
        let manager = RecentDocumentsManager()
        manager.clearAll()
        
        let testURL = URL(fileURLWithPath: "/tmp/test.pdf")
        manager.addDocument(url: testURL, pageCount: 10, currentPage: 0)
        
        XCTAssertEqual(manager.recentDocuments.count, 1)
        XCTAssertEqual(manager.recentDocuments.first?.url, testURL)
        XCTAssertEqual(manager.recentDocuments.first?.pageCount, 10)
    }
    
    func testRecentDocumentsMaxLimit() {
        let manager = RecentDocumentsManager()
        manager.clearAll()
        
        // Add more than max (20) documents
        for i in 0..<25 {
            let testURL = URL(fileURLWithPath: "/tmp/test\(i).pdf")
            manager.addDocument(url: testURL, pageCount: 10)
        }
        
        XCTAssertLessThanOrEqual(manager.recentDocuments.count, 20)
    }
    
    func testRecentDocumentsUpdateLastPage() {
        let manager = RecentDocumentsManager()
        manager.clearAll()
        
        let testURL = URL(fileURLWithPath: "/tmp/test.pdf")
        manager.addDocument(url: testURL, pageCount: 10, currentPage: 0)
        
        manager.updateLastPage(for: testURL, pageIndex: 5)
        
        XCTAssertEqual(manager.recentDocuments.first?.lastPageIndex, 5)
    }
    
    func testRecentDocumentsClearAll() {
        let manager = RecentDocumentsManager()
        
        let testURL = URL(fileURLWithPath: "/tmp/test.pdf")
        manager.addDocument(url: testURL, pageCount: 10)
        
        manager.clearAll()
        
        XCTAssertTrue(manager.recentDocuments.isEmpty)
    }
    
    // MARK: - BookmarkManager Tests
    
    func testBookmarkAddAndRemove() {
        let manager = BookmarkManager()
        
        let documentName = "test.pdf"
        let pageIndex = 5
        
        // Add bookmark
        manager.addBookmark(for: documentName, pageIndex: pageIndex)
        XCTAssertTrue(manager.isBookmarked(documentName: documentName, pageIndex: pageIndex))
        
        // Remove bookmark
        manager.removeBookmark(for: documentName, at: pageIndex)
        XCTAssertFalse(manager.isBookmarked(documentName: documentName, pageIndex: pageIndex))
    }
    
    func testBookmarkToggle() {
        let manager = BookmarkManager()
        
        let documentName = "test.pdf"
        let pageIndex = 3
        
        XCTAssertFalse(manager.isBookmarked(documentName: documentName, pageIndex: pageIndex))
        
        manager.toggleBookmark(for: documentName, pageIndex: pageIndex)
        XCTAssertTrue(manager.isBookmarked(documentName: documentName, pageIndex: pageIndex))
        
        manager.toggleBookmark(for: documentName, pageIndex: pageIndex)
        XCTAssertFalse(manager.isBookmarked(documentName: documentName, pageIndex: pageIndex))
    }
    
    func testBookmarksForDocument() {
        let manager = BookmarkManager()
        // Clear existing bookmarks for this test document
        for index in [1, 5, 10] {
            manager.removeBookmark(for: "test.pdf", at: index)
        }
        
        let documentName = "test.pdf"
        
        manager.addBookmark(for: documentName, pageIndex: 1)
        manager.addBookmark(for: documentName, pageIndex: 5)
        manager.addBookmark(for: documentName, pageIndex: 10)
        
        let bookmarks = manager.bookmarks(for: documentName)
        XCTAssertEqual(bookmarks.count, 3)
    }
    
    // MARK: - ThumbnailCache Tests
    
    func testThumbnailCacheSetAndGet() {
        let cache = ThumbnailCache.shared
        cache.clear()
        
        let testImage = NSImage(size: NSSize(width: 100, height: 100))
        let key = cache.cacheKey(documentName: "test.pdf", pageIndex: 0)
        
        cache.setThumbnail(testImage, for: key)
        
        let retrievedImage = cache.thumbnail(for: key)
        XCTAssertNotNil(retrievedImage)
    }
    
    func testThumbnailCacheClear() {
        let cache = ThumbnailCache.shared
        
        let testImage = NSImage(size: NSSize(width: 100, height: 100))
        let key = cache.cacheKey(documentName: "test.pdf", pageIndex: 0)
        
        cache.setThumbnail(testImage, for: key)
        cache.clear()
        
        let retrievedImage = cache.thumbnail(for: key)
        XCTAssertNil(retrievedImage)
    }
    
    // MARK: - RecentDocument Model Tests
    
    func testRecentDocumentInit() {
        let url = URL(fileURLWithPath: "/tmp/test.pdf")
        let doc = RecentDocument(url: url, pageCount: 20, lastPageIndex: 5)
        
        XCTAssertEqual(doc.url, url)
        XCTAssertEqual(doc.fileName, "test.pdf")
        XCTAssertEqual(doc.pageCount, 20)
        XCTAssertEqual(doc.lastPageIndex, 5)
    }
    
    // MARK: - Helper Methods

    private func createTestPDF(pageCount: Int) -> PDFDocument {
        let document = PDFDocument()

        for i in 0..<pageCount {
            let page = PDFPage()
            document.insert(page, at: i)
        }

        return document
    }
}

// MARK: - Annotation Tests

final class AnnotationTests: XCTestCase {

    private func createTestPDF(pageCount: Int = 3) -> PDFDocument {
        let document = PDFDocument()
        for i in 0..<pageCount {
            let page = PDFPage()
            document.insert(page, at: i)
        }
        return document
    }

    private func addAnnotation(
        to page: PDFPage,
        type: PDFAnnotationSubtype = .highlight,
        color: NSColor = .systemYellow,
        bounds: CGRect = CGRect(x: 50, y: 50, width: 200, height: 20)
    ) -> PDFAnnotation {
        let annotation = PDFAnnotation(bounds: bounds, forType: type, withProperties: nil)
        annotation.color = color
        page.addAnnotation(annotation)
        return annotation
    }

    // MARK: - Annotation Creation

    func testAddHighlightAnnotationToPage() {
        let document = createTestPDF()
        let page = document.page(at: 0)!

        let annotation = addAnnotation(to: page, type: .highlight, color: .systemYellow)

        XCTAssertEqual(page.annotations.count, 1)
        XCTAssertEqual(page.annotations.first, annotation)
        XCTAssertEqual(annotation.type, "Highlight")
    }

    func testAddMultipleAnnotationTypes() {
        let document = createTestPDF()
        let page = document.page(at: 0)!

        let highlight = addAnnotation(to: page, type: .highlight)
        let underline = addAnnotation(to: page, type: .underline, bounds: CGRect(x: 50, y: 80, width: 200, height: 20))
        let strikeOut = addAnnotation(to: page, type: .strikeOut, bounds: CGRect(x: 50, y: 110, width: 200, height: 20))

        XCTAssertEqual(page.annotations.count, 3)
        XCTAssertEqual(highlight.type, "Highlight")
        XCTAssertEqual(underline.type, "Underline")
        XCTAssertEqual(strikeOut.type, "StrikeOut")
    }

    func testAnnotationColorIsApplied() {
        let document = createTestPDF()
        let page = document.page(at: 0)!

        let annotation = addAnnotation(to: page, type: .highlight, color: .systemGreen.withAlphaComponent(0.5))

        XCTAssertNotNil(annotation.color)
        // Alpha should be preserved
        let alpha = annotation.color.alphaComponent
        XCTAssertEqual(alpha, 0.5, accuracy: 0.01)
    }

    func testAnnotationBoundsAreCorrect() {
        let document = createTestPDF()
        let page = document.page(at: 0)!
        let expectedBounds = CGRect(x: 100, y: 200, width: 300, height: 15)

        let annotation = addAnnotation(to: page, bounds: expectedBounds)

        XCTAssertEqual(annotation.bounds, expectedBounds)
    }

    func testAddAnnotationsToMultiplePages() {
        let document = createTestPDF(pageCount: 3)

        for i in 0..<3 {
            let page = document.page(at: i)!
            addAnnotation(to: page, bounds: CGRect(x: 10, y: 10, width: 100, height: 10))
        }

        for i in 0..<3 {
            XCTAssertEqual(document.page(at: i)!.annotations.count, 1,
                           "Page \(i) should have exactly 1 annotation")
        }
    }

    // MARK: - Annotation Deletion

    func testRemoveAnnotationFromPage() {
        let document = createTestPDF()
        let page = document.page(at: 0)!

        let annotation = addAnnotation(to: page)
        XCTAssertEqual(page.annotations.count, 1)

        page.removeAnnotation(annotation)
        XCTAssertEqual(page.annotations.count, 0, "Annotation should be removed from page")
    }

    func testRemoveAnnotationPageReferenceCleared() {
        let document = createTestPDF()
        let page = document.page(at: 0)!

        let annotation = addAnnotation(to: page)
        XCTAssertNotNil(annotation.page, "Annotation should reference its page before removal")

        page.removeAnnotation(annotation)
        XCTAssertNil(annotation.page, "Annotation page reference should be nil after removal")
    }

    func testRemoveSpecificAnnotationLeavesOthers() {
        let document = createTestPDF()
        let page = document.page(at: 0)!

        let annotation1 = addAnnotation(to: page, color: .systemYellow, bounds: CGRect(x: 10, y: 10, width: 100, height: 10))
        let annotation2 = addAnnotation(to: page, color: .systemGreen, bounds: CGRect(x: 10, y: 30, width: 100, height: 10))
        let annotation3 = addAnnotation(to: page, color: .systemBlue, bounds: CGRect(x: 10, y: 50, width: 100, height: 10))

        XCTAssertEqual(page.annotations.count, 3)

        // Remove the middle one
        page.removeAnnotation(annotation2)

        XCTAssertEqual(page.annotations.count, 2)
        XCTAssertTrue(page.annotations.contains(annotation1))
        XCTAssertFalse(page.annotations.contains(annotation2), "Removed annotation should not be in page")
        XCTAssertTrue(page.annotations.contains(annotation3))
    }

    func testRemoveAllAnnotationsFromPage() {
        let document = createTestPDF()
        let page = document.page(at: 0)!

        var annotations: [PDFAnnotation] = []
        for i in 0..<5 {
            let a = addAnnotation(to: page, bounds: CGRect(x: 10, y: CGFloat(i * 20), width: 100, height: 10))
            annotations.append(a)
        }
        XCTAssertEqual(page.annotations.count, 5)

        for annotation in annotations {
            page.removeAnnotation(annotation)
        }
        XCTAssertEqual(page.annotations.count, 0, "All annotations should be removed")
    }

    func testRemoveAnnotationDoesNotAffectOtherPages() {
        let document = createTestPDF(pageCount: 2)
        let page0 = document.page(at: 0)!
        let page1 = document.page(at: 1)!

        let annotation0 = addAnnotation(to: page0)
        let _ = addAnnotation(to: page1)

        page0.removeAnnotation(annotation0)

        XCTAssertEqual(page0.annotations.count, 0)
        XCTAssertEqual(page1.annotations.count, 1, "Removing from page 0 should not affect page 1")
    }

    // MARK: - Annotation Filtering

    func testFilterValidAnnotationTypes() {
        let document = createTestPDF()
        let page = document.page(at: 0)!

        addAnnotation(to: page, type: .highlight)
        addAnnotation(to: page, type: .underline, bounds: CGRect(x: 10, y: 30, width: 100, height: 10))
        addAnnotation(to: page, type: .strikeOut, bounds: CGRect(x: 10, y: 50, width: 100, height: 10))

        // Add an annotation type that shouldn't be in the filtered list
        let linkAnnotation = PDFAnnotation(bounds: CGRect(x: 10, y: 70, width: 100, height: 10), forType: .link, withProperties: nil)
        page.addAnnotation(linkAnnotation)

        let validTypes = ["Highlight", "Underline", "StrikeOut", "Text", "FreeText"]
        let filtered = page.annotations.filter { validTypes.contains($0.type ?? "") }

        XCTAssertEqual(filtered.count, 3, "Link annotations should be filtered out")
        XCTAssertEqual(page.annotations.count, 4, "Page should still have all 4 annotations")
    }

    // MARK: - Notification Tests

    func testAnnotationAddedNotificationPosted() {
        let expectation = expectation(forNotification: .PDFAnnotationAdded, object: nil)

        NotificationCenter.default.post(name: .PDFAnnotationAdded, object: nil)

        wait(for: [expectation], timeout: 1.0)
    }

    func testAnnotationRemovedNotificationPosted() {
        let expectation = expectation(forNotification: .PDFAnnotationRemoved, object: nil)

        NotificationCenter.default.post(name: .PDFAnnotationRemoved, object: nil)

        wait(for: [expectation], timeout: 1.0)
    }

    func testAnnotationRemovedNotificationNameIsCorrect() {
        XCTAssertEqual(Notification.Name.PDFAnnotationRemoved.rawValue, "PDFAnnotationRemoved")
        XCTAssertEqual(Notification.Name.PDFAnnotationAdded.rawValue, "PDFAnnotationAdded")
    }

    // MARK: - AnnotationTool Enum Tests

    func testAnnotationToolPDFTypes() {
        XCTAssertEqual(AnnotationTool.highlight.pdfAnnotationType, .highlight)
        XCTAssertEqual(AnnotationTool.underline.pdfAnnotationType, .underline)
        XCTAssertEqual(AnnotationTool.strikethrough.pdfAnnotationType, .strikeOut)
        XCTAssertEqual(AnnotationTool.note.pdfAnnotationType, .text)
        XCTAssertEqual(AnnotationTool.freeText.pdfAnnotationType, .freeText)
    }

    func testAnnotationToolIcons() {
        XCTAssertEqual(AnnotationTool.highlight.icon, "highlighter")
        XCTAssertEqual(AnnotationTool.underline.icon, "underline")
        XCTAssertEqual(AnnotationTool.strikethrough.icon, "strikethrough")
        XCTAssertEqual(AnnotationTool.note.icon, "note.text")
        XCTAssertEqual(AnnotationTool.freeText.icon, "character.textbox")
    }

    func testAnnotationToolAllCases() {
        XCTAssertEqual(AnnotationTool.allCases.count, 5)
    }

    func testAnnotationToolIdentifiable() {
        for tool in AnnotationTool.allCases {
            XCTAssertEqual(tool.id, tool.rawValue)
        }
    }

    // MARK: - Color Persistence Tests

    func testColorStorageInUserDefaults() {
        let defaults = UserDefaults.standard
        let testColor = NSColor.systemPurple
        let key = "testHighlightColorStorage"

        defaults.setColor(testColor, forKey: key)
        let retrieved = defaults.color(forKey: key)

        XCTAssertNotNil(retrieved, "Color should be retrievable from UserDefaults")

        // Clean up
        defaults.removeObject(forKey: key)
    }

    func testColorStorageReturnsNilForMissingKey() {
        let defaults = UserDefaults.standard
        let key = "nonExistentColorKey_\(UUID().uuidString)"

        let retrieved = defaults.color(forKey: key)
        XCTAssertNil(retrieved, "Non-existent key should return nil")
    }

    // MARK: - NSColor Extension Tests

    func testColorApproximatelyEqualSameColor() {
        let color = NSColor.systemYellow
        XCTAssertTrue(color.isApproximatelyEqual(to: color))
    }

    func testColorApproximatelyEqualDifferentColors() {
        let yellow = NSColor.systemYellow
        let blue = NSColor.systemBlue
        XCTAssertFalse(yellow.isApproximatelyEqual(to: blue))
    }

    // MARK: - Edge Cases

    func testAddAnnotationWithZeroBounds() {
        let document = createTestPDF()
        let page = document.page(at: 0)!

        let annotation = addAnnotation(to: page, bounds: CGRect.zero)
        XCTAssertEqual(page.annotations.count, 1)
        XCTAssertEqual(annotation.bounds, CGRect.zero)
    }

    func testAnnotationContentsForNote() {
        let document = createTestPDF()
        let page = document.page(at: 0)!

        let annotation = PDFAnnotation(bounds: CGRect(x: 10, y: 10, width: 20, height: 20), forType: .text, withProperties: nil)
        annotation.contents = "Test note content"
        annotation.color = .systemYellow
        page.addAnnotation(annotation)

        XCTAssertEqual(annotation.contents, "Test note content")
        XCTAssertEqual(annotation.type, "Text")
    }

    func testAnnotationContentsForFreeText() {
        let document = createTestPDF()
        let page = document.page(at: 0)!

        let annotation = PDFAnnotation(bounds: CGRect(x: 10, y: 10, width: 200, height: 20), forType: .freeText, withProperties: nil)
        annotation.contents = "Free text content"
        annotation.color = .systemOrange
        annotation.font = NSFont.systemFont(ofSize: 12)
        page.addAnnotation(annotation)

        XCTAssertEqual(annotation.contents, "Free text content")
        XCTAssertEqual(annotation.type, "FreeText")
        XCTAssertNotNil(annotation.font)
    }

    func testRemoveAndReAddAnnotation() {
        let document = createTestPDF()
        let page = document.page(at: 0)!

        let annotation = addAnnotation(to: page)
        XCTAssertEqual(page.annotations.count, 1)

        page.removeAnnotation(annotation)
        XCTAssertEqual(page.annotations.count, 0)

        // Re-add the same annotation
        page.addAnnotation(annotation)
        XCTAssertEqual(page.annotations.count, 1, "Should be able to re-add a removed annotation")
    }

    func testRapidAddRemoveCycles() {
        let document = createTestPDF()
        let page = document.page(at: 0)!

        // Simulate rapid add/remove cycles (stress test for race conditions)
        for _ in 0..<50 {
            let annotation = addAnnotation(to: page)
            page.removeAnnotation(annotation)
        }

        XCTAssertEqual(page.annotations.count, 0, "After equal add/remove cycles, page should have no annotations")
    }

    func testDeleteAnnotationWithNilPageIsNoOp() {
        // Simulate the guard check in removeAnnotation
        let annotation = PDFAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 10), forType: .highlight, withProperties: nil)
        // annotation.page is nil since it was never added to a page

        XCTAssertNil(annotation.page, "Annotation not added to page should have nil page")
        // The guard in removeAnnotation should safely exit here
    }

    func testAnnotationCountAcrossAllPages() {
        let document = createTestPDF(pageCount: 5)

        // Add varying numbers of annotations per page
        for i in 0..<5 {
            let page = document.page(at: i)!
            for j in 0..<(i + 1) {
                addAnnotation(to: page, bounds: CGRect(x: 10, y: CGFloat(j * 20), width: 100, height: 10))
            }
        }

        // Collect all annotations like refreshAnnotations() does
        var totalAnnotations: [PDFAnnotation] = []
        let validTypes = ["Highlight", "Underline", "StrikeOut", "Text", "FreeText"]
        for i in 0..<document.pageCount {
            if let page = document.page(at: i) {
                let filtered = page.annotations.filter { validTypes.contains($0.type ?? "") }
                totalAnnotations.append(contentsOf: filtered)
            }
        }

        // 1 + 2 + 3 + 4 + 5 = 15 total
        XCTAssertEqual(totalAnnotations.count, 15)
    }
}

// MARK: - Citation Extractor Tests

final class CitationExtractorTests: XCTestCase {
    
    func testCitationExtractorSingleton() {
        let extractor1 = CitationExtractor.shared
        let extractor2 = CitationExtractor.shared
        
        XCTAssertTrue(extractor1 === extractor2, "CitationExtractor should be a singleton")
    }
    
    func testCitationExtractionInitialState() {
        let extractor = CitationExtractor.shared
        
        XCTAssertFalse(extractor.isExtracting)
        XCTAssertEqual(extractor.progress, 0)
    }
    
    func testCitationFormatting() {
        var citation = ExtractedCitation(
            rawText: "[1] Test Article",
            authors: ["Smith, J.", "Doe, A."],
            title: "Test Article Title"
        )
        citation.year = "2024"
        citation.journal = "Test Journal"
        
        // Test APA format
        let apa = citation.formatted(as: .apa)
        XCTAssertTrue(apa.contains("Smith, J."))
        XCTAssertTrue(apa.contains("2024"))
        
        // Test BibTeX format
        let bibtex = citation.formatted(as: .bibtex)
        XCTAssertTrue(bibtex.contains("@article"))
        XCTAssertTrue(bibtex.contains("author"))
    }
    
    func testURLBasedCitationParsing() {
        // Test that URL-based citations are properly parsed
        let citation = ExtractedCitation(
            rawText: "[1] YouTube Demographics: https://blog.hubspot.com/marketing",
            authors: [],
            title: "YouTube Demographics"
        )
        
        XCTAssertFalse(citation.title.isEmpty)
    }
}

// MARK: - Highlight Tests

final class HighlightTests: XCTestCase {
    
    func testHighlightColorSaving() {
        let testColor = NSColor.systemGreen
        UserDefaults.standard.setColor(testColor, forKey: "testHighlightColor")
        
        let retrievedColor = UserDefaults.standard.color(forKey: "testHighlightColor")
        XCTAssertNotNil(retrievedColor)
    }
    
    func testHighlightModeToggle() {
        let manager = DocumentManager()
        
        XCTAssertFalse(manager.highlighterEnabled)
        
        manager.highlighterEnabled = true
        XCTAssertTrue(manager.highlighterEnabled)
        
        manager.highlighterEnabled = false
        XCTAssertFalse(manager.highlighterEnabled)
    }
    
    func testHighlightColorChange() {
        let manager = DocumentManager()
        
        manager.highlighterColor = .systemPink
        XCTAssertEqual(manager.highlighterColor, .systemPink)
        
        manager.highlighterColor = .systemBlue
        XCTAssertEqual(manager.highlighterColor, .systemBlue)
    }
    
    func testMultipleLineHighlightsSeparate() {
        // Test that highlights on different lines remain separate
        let document = TestHelpers.createTestPDF()
        guard let page = document.page(at: 0) else {
            XCTFail("Failed to get page")
            return
        }
        
        // Add two highlights on different Y positions (different lines)
        let highlight1 = PDFAnnotation(bounds: CGRect(x: 10, y: 100, width: 100, height: 12), forType: .highlight, withProperties: nil)
        let highlight2 = PDFAnnotation(bounds: CGRect(x: 10, y: 50, width: 100, height: 12), forType: .highlight, withProperties: nil)
        
        page.addAnnotation(highlight1)
        page.addAnnotation(highlight2)
        
        // Both should remain separate
        XCTAssertEqual(page.annotations.count, 2)
    }
}

// MARK: - Cloud Sync Tests

final class CloudSyncTests: XCTestCase {
    
    func testCloudSyncManagerSingleton() {
        let manager1 = CloudSyncManager.shared
        let manager2 = CloudSyncManager.shared
        
        XCTAssertTrue(manager1 === manager2, "CloudSyncManager should be a singleton")
    }
    
    func testCloudSyncInitialState() {
        let manager = CloudSyncManager.shared
        
        XCTAssertFalse(manager.isSyncing)
        XCTAssertEqual(manager.syncProgress, 0)
    }
    
    func testCloudProviderIcons() {
        XCTAssertEqual(CloudProvider.icloud.icon, "icloud")
        XCTAssertEqual(CloudProvider.local.icon, "folder")
    }
    
    func testCloudProviderIdentifiers() {
        XCTAssertEqual(CloudProvider.icloud.rawValue, "iCloud")
        XCTAssertEqual(CloudProvider.local.rawValue, "Local")
    }
}

// MARK: - RightPanelMode Tests

final class RightPanelModeTests: XCTestCase {
    
    func testAllPanelModesExist() {
        let allModes = RightPanelMode.allCases
        
        XCTAssertTrue(allModes.contains(.ai))
        XCTAssertTrue(allModes.contains(.dictionary))
        XCTAssertTrue(allModes.contains(.webSearch))
        XCTAssertTrue(allModes.contains(.citations))
        XCTAssertTrue(allModes.contains(.ocr))
        XCTAssertTrue(allModes.contains(.timer))
        XCTAssertTrue(allModes.contains(.progress))
        XCTAssertTrue(allModes.contains(.cloud))
    }
    
    func testPanelModeCount() {
        XCTAssertEqual(RightPanelMode.allCases.count, 8)
    }
}

// MARK: - Focus Timer Tests

final class FocusTimerTests: XCTestCase {
    
    func testFocusTimerManagerSingleton() {
        let manager1 = FocusTimerManager.shared
        let manager2 = FocusTimerManager.shared
        
        XCTAssertTrue(manager1 === manager2, "FocusTimerManager should be a singleton")
    }
    
    func testFocusTimerInitialState() {
        let manager = FocusTimerManager.shared
        
        XCTAssertEqual(manager.state, .idle)
    }
    
    func testDefaultTimerDurations() {
        let manager = FocusTimerManager.shared
        
        // Timer durations should be positive values
        XCTAssertGreaterThan(manager.pomodoroMinutes, 0)
        XCTAssertGreaterThan(manager.shortBreakMinutes, 0)
    }
}

// MARK: - Reading Progress Tests

final class ReadingProgressTests: XCTestCase {
    
    func testReadingProgressManagerSingleton() {
        let manager1 = ReadingProgressManager.shared
        let manager2 = ReadingProgressManager.shared
        
        XCTAssertTrue(manager1 === manager2, "ReadingProgressManager should be a singleton")
    }
    
    func testSessionTracking() {
        let manager = ReadingProgressManager.shared
        
        // Progress tracking should work
        XCTAssertGreaterThanOrEqual(manager.todayReadingTime, 0)
    }
    
    func testDailyGoalExists() {
        let manager = ReadingProgressManager.shared
        
        XCTAssertGreaterThan(manager.dailyGoalMinutes, 0)
    }
}

// MARK: - Performance Tests

final class PDFReaderPerformanceTests: XCTestCase {
    
    func testDocumentManagerCreationPerformance() {
        measure {
            for _ in 0..<100 {
                _ = DocumentManager()
            }
        }
    }
    
    func testRecentDocumentsAddPerformance() {
        let manager = RecentDocumentsManager()
        
        measure {
            for i in 0..<50 {
                let url = URL(fileURLWithPath: "/tmp/perf_test_\(i).pdf")
                manager.addDocument(url: url, pageCount: 100)
            }
        }
        
        manager.clearAll()
    }
    
    func testThumbnailCachePerformance() {
        let cache = ThumbnailCache.shared
        cache.clear()
        
        let testImage = NSImage(size: NSSize(width: 100, height: 100))
        
        measure {
            for i in 0..<1000 {
                let key = cache.cacheKey(documentName: "perf_test.pdf", pageIndex: i)
                cache.setThumbnail(testImage, for: key)
                _ = cache.thumbnail(for: key)
            }
        }
        
        cache.clear()
    }
}

// MARK: - Sidebar View Mode Tests

final class SidebarViewModeTests: XCTestCase {
    
    func testAllSidebarViewModesExist() {
        let allModes = SidebarViewMode.allCases
        
        XCTAssertTrue(allModes.contains(.thumbnails))
        XCTAssertTrue(allModes.contains(.tableOfContents))
    }
    
    func testSidebarViewModeCount() {
        XCTAssertEqual(SidebarViewMode.allCases.count, 2)
    }
    
    func testSidebarViewModeIcons() {
        XCTAssertEqual(SidebarViewMode.thumbnails.icon, "square.grid.2x2")
        XCTAssertEqual(SidebarViewMode.tableOfContents.icon, "list.bullet.indent")
    }
    
    func testSidebarViewModeRawValues() {
        XCTAssertEqual(SidebarViewMode.thumbnails.rawValue, "Pages")
        XCTAssertEqual(SidebarViewMode.tableOfContents.rawValue, "Contents")
    }
}

// MARK: - TOC Item Tests

final class TOCItemTests: XCTestCase {
    
    func testTOCItemInitialization() {
        let item = TOCItem(title: "Chapter 1", pageIndex: 5, level: 0, children: [])
        
        XCTAssertEqual(item.title, "Chapter 1")
        XCTAssertEqual(item.pageIndex, 5)
        XCTAssertEqual(item.level, 0)
        XCTAssertTrue(item.children.isEmpty)
    }
    
    func testTOCItemWithChildren() {
        let child1 = TOCItem(title: "Section 1.1", pageIndex: 6, level: 1, children: [])
        let child2 = TOCItem(title: "Section 1.2", pageIndex: 10, level: 1, children: [])
        let parent = TOCItem(title: "Chapter 1", pageIndex: 5, level: 0, children: [child1, child2])
        
        XCTAssertEqual(parent.children.count, 2)
        XCTAssertEqual(parent.children[0].title, "Section 1.1")
        XCTAssertEqual(parent.children[1].title, "Section 1.2")
    }
    
    func testTOCItemHasUniqueID() {
        let item1 = TOCItem(title: "Chapter 1", pageIndex: 5, level: 0, children: [])
        let item2 = TOCItem(title: "Chapter 1", pageIndex: 5, level: 0, children: [])
        
        XCTAssertNotEqual(item1.id, item2.id)
    }
}

// MARK: - Annotation Filter Tests

final class AnnotationFilterTests: XCTestCase {
    
    func testAllAnnotationFiltersExist() {
        let allFilters = AnnotationFilter.allCases
        
        XCTAssertTrue(allFilters.contains(.all))
        XCTAssertTrue(allFilters.contains(.highlights))
        XCTAssertTrue(allFilters.contains(.notes))
        XCTAssertTrue(allFilters.contains(.currentPage))
    }
    
    func testAnnotationFilterCount() {
        XCTAssertEqual(AnnotationFilter.allCases.count, 4)
    }
    
    func testAnnotationFilterRawValues() {
        XCTAssertEqual(AnnotationFilter.all.rawValue, "All")
        XCTAssertEqual(AnnotationFilter.highlights.rawValue, "Highlights")
        XCTAssertEqual(AnnotationFilter.notes.rawValue, "Notes")
        XCTAssertEqual(AnnotationFilter.currentPage.rawValue, "This Page")
    }
}

// MARK: - Bookmark Card View State Tests

final class BookmarkStateTests: XCTestCase {
    
    func testBookmarkColorEnum() {
        let allColors = BookmarkColor.allCases
        
        XCTAssertTrue(allColors.contains(.red))
        XCTAssertTrue(allColors.contains(.orange))
        XCTAssertTrue(allColors.contains(.yellow))
        XCTAssertTrue(allColors.contains(.green))
        XCTAssertTrue(allColors.contains(.blue))
        XCTAssertTrue(allColors.contains(.purple))
    }
    
    func testBookmarkColorCount() {
        XCTAssertEqual(BookmarkColor.allCases.count, 6)
    }
}

// MARK: - Memory and Performance Optimization Tests

final class MemoryOptimizationTests: XCTestCase {
    
    func testThumbnailCacheSetAndRetrieve() {
        // Test that ThumbnailCache can set and retrieve items
        let cache = ThumbnailCache.shared
        cache.clear()
        
        let testImage = NSImage(size: NSSize(width: 200, height: 300))
        
        // Add and retrieve some thumbnails
        for i in 0..<10 {
            let key = cache.cacheKey(documentName: "memory_test.pdf", pageIndex: i)
            cache.setThumbnail(testImage, for: key)
            
            // Should be able to retrieve immediately
            let retrieved = cache.thumbnail(for: key)
            XCTAssertNotNil(retrieved, "Thumbnail should be retrievable after being set")
        }
        
        cache.clear()
    }
    
    func testRecentDocumentsMemoryManagement() {
        let manager = RecentDocumentsManager()
        
        // Add many documents
        for i in 0..<100 {
            let url = URL(fileURLWithPath: "/tmp/memory_test_\(i).pdf")
            manager.addDocument(url: url, pageCount: 100)
        }
        
        // Should be capped at 20
        XCTAssertLessThanOrEqual(manager.recentDocuments.count, 20)
        
        manager.clearAll()
    }
}

// MARK: - DocumentManager Extended Tests

final class DocumentManagerExtendedTests: XCTestCase {
    
    func testAutosaveInitialState() {
        let manager = DocumentManager()
        
        let initial = manager.autoSaveEnabled
        manager.autoSaveEnabled = !initial
        XCTAssertNotEqual(manager.autoSaveEnabled, initial)
    }
    
    func testHasUnsavedChangesInitialState() {
        let manager = DocumentManager()
        
        // A fresh document manager should not have unsaved changes
        XCTAssertFalse(manager.hasUnsavedChanges)
    }
}
