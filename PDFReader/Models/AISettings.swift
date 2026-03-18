//
//  AISettings.swift
//  PDFReader
//
//  AI assistant configuration and models
//

import Foundation

struct AISettings: Codable {
    var provider: AIProvider
    var apiKey: String
    var localModelPath: String
    var maxTokens: Int
    var temperature: Double
    
    init() {
        self.provider = .openAI
        self.apiKey = ""
        self.localModelPath = ""
        self.maxTokens = 2048
        self.temperature = 0.7
    }
}

enum AIProvider: String, Codable, CaseIterable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic"
    case localLLM = "Local LLM"
    case ollama = "Ollama"
    
    var requiresAPIKey: Bool {
        switch self {
        case .openAI, .anthropic: return true
        case .localLLM, .ollama: return false
        }
    }
    
    var baseURL: String {
        switch self {
        case .openAI: return "https://api.openai.com/v1/chat/completions"
        case .anthropic: return "https://api.anthropic.com/v1/messages"
        case .localLLM: return ""
        case .ollama: return "http://localhost:11434/api/generate"
        }
    }
}

struct AIMessage: Identifiable, Equatable {
    let id = UUID()
    var role: AIRole
    var content: String
    var timestamp: Date = Date()
}

enum AIRole: String, Codable {
    case user
    case assistant
    case system
}

struct AIResponse: Codable {
    // OpenAI format
    struct OpenAIResponse: Codable {
        struct Choice: Codable {
            struct Message: Codable {
                var content: String
            }
            var message: Message
        }
        var choices: [Choice]
    }
    
    // Anthropic format
    struct AnthropicResponse: Codable {
        struct Content: Codable {
            var text: String
        }
        var content: [Content]
    }
    
    // Ollama format
    struct OllamaResponse: Codable {
        var response: String
    }
}
