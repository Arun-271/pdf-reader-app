//
//  AIAssistantManagerTests.swift
//  PDFReaderTests
//
//  Tests for AI Assistant Manager
//

import XCTest
@testable import PDFReader

final class AIAssistantManagerTests: XCTestCase {
    
    var manager: AIAssistantManager!
    let testKey = "PDFReaderAISettings_Test"
    
    override func setUp() {
        super.setUp()
        // Clear test defaults
        UserDefaults.standard.removeObject(forKey: "PDFReaderAISettings")
        manager = AIAssistantManager()
    }
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "PDFReaderAISettings")
        manager = nil
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertTrue(manager.messages.isEmpty)
        XCTAssertFalse(manager.isLoading)
        XCTAssertNil(manager.errorMessage)
    }
    
    func testClearMessages() {
        // We can't easily populate messages without AIMessage init, but let's assume AIMessage isn't completely hidden.
        manager.messages = [AIMessage(role: .user, content: "Test")]
        XCTAssertFalse(manager.messages.isEmpty)
        
        manager.clearMessages()
        XCTAssertTrue(manager.messages.isEmpty)
    }
    
    func testSaveSettings() {
        manager.settings.apiKey = "test-key"
        manager.settings.maxTokens = 1000
        manager.saveSettings()
        
        // Create new manager to check if settings persisted
        let newManager = AIAssistantManager()
        XCTAssertEqual(newManager.settings.apiKey, "test-key")
        XCTAssertEqual(newManager.settings.maxTokens, 1000)
    }
    
    func testSendMessageAppendsUserRole() async {
        // Send a message without a real API key will throw an error eventually, 
        // but it should at least immediately append the user's message.
        await manager.sendMessage("Hello World", context: nil)
        
        // Assert that the user's message is first
        XCTAssertGreaterThanOrEqual(manager.messages.count, 1)
        XCTAssertEqual(manager.messages.first?.content, "Hello World")
        XCTAssertEqual(manager.messages.first?.role, .user)
        
        // Since there is no mock, it likely threw missingAPIKey and populated errorMessage
        XCTAssertNotNil(manager.errorMessage)
        XCTAssertFalse(manager.isLoading)
    }
}
