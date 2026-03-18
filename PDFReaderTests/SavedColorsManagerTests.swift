//
//  SavedColorsManagerTests.swift
//  PDFReaderTests
//
//  Tests for Saved Colors Manager
//

import XCTest
@testable import PDFReader

final class SavedColorsManagerTests: XCTestCase {
    
    var manager: SavedColorsManager!
    
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "savedCustomHighlightColors")
        // Since it's a singleton, we need to manually clear its memory state
        SavedColorsManager.shared.colors.removeAll()
        manager = SavedColorsManager.shared
    }
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "savedCustomHighlightColors")
        manager.colors.removeAll()
        manager = nil
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertTrue(manager.colors.isEmpty)
    }
    
    func testAddColor() {
        let color = PlatformColor.systemRed
        manager.addColor(color)
        
        XCTAssertEqual(manager.colors.count, 1)
        XCTAssertTrue(manager.colors.first?.isApproximatelyEqual(to: color) == true)
    }
    
    func testAddColorDeduplication() {
        let color = PlatformColor.systemBlue
        manager.addColor(color)
        manager.addColor(color) // Try adding same color again
        
        // It shouldn't add duplicates based on `isApproximatelyEqual`
        XCTAssertEqual(manager.colors.count, 1)
    }
    
    func testMaxColorsLimit() {
        // Add 15 unique colors (max is 12)
        for i in 0..<15 {
            let color = PlatformColor(red: CGFloat(i)/255.0, green: 0, blue: 0, alpha: 1.0)
            manager.addColor(color)
        }
        
        XCTAssertLessThanOrEqual(manager.colors.count, 12)
    }
    
    func testRemoveColor() {
        let color = PlatformColor.systemYellow
        manager.addColor(color)
        XCTAssertEqual(manager.colors.count, 1)
        
        manager.removeColor(color)
        XCTAssertTrue(manager.colors.isEmpty)
    }
    
    func testRemoveColorAtIndex() {
        let color1 = PlatformColor.systemGreen
        let color2 = PlatformColor.systemPurple
        
        // addColor inserts at index 0
        manager.addColor(color1)
        manager.addColor(color2)
        
        XCTAssertEqual(manager.colors.count, 2)
        
        // color2 is at index 0, color1 is at index 1
        manager.removeColorAt(0)
        
        XCTAssertEqual(manager.colors.count, 1)
        XCTAssertTrue(manager.colors.first?.isApproximatelyEqual(to: color1) == true)
    }
    
    func testPersistence() {
        let color = PlatformColor.systemOrange
        manager.addColor(color)
        
        // Load should read from UserDefaults
        manager.colors.removeAll() // Clear memory
        XCTAssertTrue(manager.colors.isEmpty)
        
        manager.loadColors()
        XCTAssertEqual(manager.colors.count, 1)
        XCTAssertTrue(manager.colors.first?.isApproximatelyEqual(to: color) == true)
    }
}
