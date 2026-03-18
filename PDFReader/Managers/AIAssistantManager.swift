//
//  AIAssistantManager.swift
//  PDFReader
//
//  Manages AI assistant functionality
//

import SwiftUI
import Combine

class AIAssistantManager: ObservableObject {
    @Published var messages: [AIMessage] = []
    @Published var isLoading: Bool = false
    @Published var settings: AISettings
    @Published var errorMessage: String?
    
    private let settingsKey = "PDFReaderAISettings"
    
    init() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(AISettings.self, from: data) {
            settings = decoded
        } else {
            settings = AISettings()
        }
    }
    
    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }
    
    func clearMessages() {
        messages.removeAll()
    }
    
    func sendMessage(_ content: String, context: String? = nil) async {
        let userMessage = AIMessage(role: .user, content: content)
        
        await MainActor.run {
            messages.append(userMessage)
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let response = try await performAIRequest(message: content, context: context)
            let assistantMessage = AIMessage(role: .assistant, content: response)
            
            await MainActor.run {
                messages.append(assistantMessage)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    private func performAIRequest(message: String, context: String?) async throws -> String {
        switch settings.provider {
        case .openAI:
            return try await callOpenAI(message: message, context: context)
        case .anthropic:
            return try await callAnthropic(message: message, context: context)
        case .ollama:
            return try await callOllama(message: message, context: context)
        case .localLLM:
            return "Local LLM support requires additional setup. Please configure a local model path in settings."
        }
    }
    
    private func callOpenAI(message: String, context: String?) async throws -> String {
        guard !settings.apiKey.isEmpty else {
            throw AIError.missingAPIKey
        }
        
        var systemPrompt = "You are a helpful AI assistant for a PDF reader application. Help users understand and analyze PDF documents."
        if let ctx = context {
            systemPrompt += "\n\nCurrent PDF context:\n\(ctx)"
        }
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": message]
            ],
            "max_tokens": settings.maxTokens,
            "temperature": settings.temperature
        ]
        
        var request = URLRequest(url: URL(string: settings.provider.baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AIError.requestFailed
        }
        
        let decoded = try JSONDecoder().decode(AIResponse.OpenAIResponse.self, from: data)
        return decoded.choices.first?.message.content ?? "No response"
    }
    
    private func callAnthropic(message: String, context: String?) async throws -> String {
        guard !settings.apiKey.isEmpty else {
            throw AIError.missingAPIKey
        }
        
        var systemPrompt = "You are a helpful AI assistant for a PDF reader application."
        if let ctx = context {
            systemPrompt += "\n\nCurrent PDF context:\n\(ctx)"
        }
        
        let requestBody: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": settings.maxTokens,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": message]
            ]
        ]
        
        var request = URLRequest(url: URL(string: settings.provider.baseURL)!)
        request.httpMethod = "POST"
        request.setValue(settings.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AIError.requestFailed
        }
        
        let decoded = try JSONDecoder().decode(AIResponse.AnthropicResponse.self, from: data)
        return decoded.content.first?.text ?? "No response"
    }
    
    private func callOllama(message: String, context: String?) async throws -> String {
        var prompt = message
        if let ctx = context {
            prompt = "Context from PDF:\n\(ctx)\n\nUser question: \(message)"
        }
        
        let requestBody: [String: Any] = [
            "model": "llama2",
            "prompt": prompt,
            "stream": false
        ]
        
        var request = URLRequest(url: URL(string: settings.provider.baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AIError.requestFailed
        }
        
        let decoded = try JSONDecoder().decode(AIResponse.OllamaResponse.self, from: data)
        return decoded.response
    }
}

enum AIError: LocalizedError {
    case missingAPIKey
    case requestFailed
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key is required. Please add your API key in Settings."
        case .requestFailed:
            return "Failed to get response from AI service."
        case .invalidResponse:
            return "Invalid response from AI service."
        }
    }
}
