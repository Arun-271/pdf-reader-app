//
//  AIAssistantView.swift
//  PDFReader
//
//  AI assistant panel for asking questions about the PDF
//

import SwiftUI

struct AIAssistantView: View {
    @EnvironmentObject var documentManager: DocumentManager
    @EnvironmentObject var aiManager: AIAssistantManager
    @State private var inputText: String = ""
    @State private var showSettings = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("AI Assistant")
                    .font(.headline)
                Spacer()
                
                Button(action: { showSettings = true }) {
                    Image(systemName: "gear")
                }
                .buttonStyle(.borderless)
                .help("AI Settings")
                
                Button(action: { aiManager.clearMessages() }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .disabled(aiManager.messages.isEmpty)
                .help("Clear conversation")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Provider indicator
            HStack {
                Circle()
                    .fill(aiManager.settings.apiKey.isEmpty && aiManager.settings.provider.requiresAPIKey ? Color.orange : Color.green)
                    .frame(width: 8, height: 8)
                Text(aiManager.settings.provider.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            
            Divider()
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if aiManager.messages.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                
                                Text("Ask AI about the PDF")
                                    .foregroundColor(.secondary)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    SuggestionButton("Summarize this document") {
                                        sendMessage("Please summarize this PDF document.")
                                    }
                                    SuggestionButton("Explain the main points") {
                                        sendMessage("What are the main points of this document?")
                                    }
                                    SuggestionButton("Find key information") {
                                        sendMessage("What are the key pieces of information in this document?")
                                    }
                                }
                            }
                            .padding(.top, 40)
                        }
                        
                        ForEach(aiManager.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        
                        if aiManager.isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Thinking...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                        }
                        
                        if let error = aiManager.errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                        }
                    }
                    .padding()
                }
                .onChange(of: aiManager.messages.count) { _ in
                    if let lastMessage = aiManager.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Input area
            HStack(spacing: 8) {
                TextField("Ask about the PDF...", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isInputFocused)
                    .onSubmit {
                        sendMessage(inputText)
                    }
                    .disabled(aiManager.isLoading)
                
                Button(action: { sendMessage(inputText) }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                }
                .buttonStyle(.borderless)
                .disabled(inputText.isEmpty || aiManager.isLoading)
            }
            .padding(12)
        }
        .sheet(isPresented: $showSettings) {
            AISettingsView()
                .environmentObject(aiManager)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AskAIPasteText"))) { notification in
            if let text = notification.object as? String {
                inputText = text
                // Optional: slight delay to ensure the view draws before focusing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isInputFocused = true
                }
            }
        }
    }
    
    private func sendMessage(_ text: String) {
        guard !text.isEmpty else { return }
        
        let context = getCurrentPageText()
        inputText = ""
        
        Task {
            await aiManager.sendMessage(text, context: context)
        }
    }
    
    private func getCurrentPageText() -> String? {
        guard let page = documentManager.currentPage else { return nil }
        return page.string
    }
}

struct MessageBubble: View {
    let message: AIMessage
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(10)
                    .background(message.role == .user ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .cornerRadius(12)
                
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if message.role == .assistant {
                Spacer()
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct SuggestionButton: View {
    let text: String
    let action: () -> Void
    
    init(_ text: String, action: @escaping () -> Void) {
        self.text = text
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(16)
        }
        .buttonStyle(.borderless)
    }
}

struct AISettingsView: View {
    @EnvironmentObject var aiManager: AIAssistantManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            Text("AI Settings")
                .font(.headline)
            
            Form {
                Picker("Provider", selection: $aiManager.settings.provider) {
                    ForEach(AIProvider.allCases, id: \.self) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                
                if aiManager.settings.provider.requiresAPIKey {
                    SecureField("API Key", text: $aiManager.settings.apiKey)
                        .textFieldStyle(.roundedBorder)
                }
                
                if aiManager.settings.provider == .ollama {
                    Text("Make sure Ollama is running locally on port 11434")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if aiManager.settings.provider == .localLLM {
                    TextField("Model Path", text: $aiManager.settings.localModelPath)
                        .textFieldStyle(.roundedBorder)
                }
                
                Slider(value: $aiManager.settings.temperature, in: 0...1, step: 0.1) {
                    Text("Temperature: \(aiManager.settings.temperature, specifier: "%.1f")")
                }
                
                Stepper("Max Tokens: \(aiManager.settings.maxTokens)", value: $aiManager.settings.maxTokens, in: 100...4000, step: 100)
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Save") {
                    aiManager.saveSettings()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
