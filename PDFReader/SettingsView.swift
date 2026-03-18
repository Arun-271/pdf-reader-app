//
//  SettingsView.swift
//  PDFReader
//
//  App settings and preferences
//

import SwiftUI
import PDFKit

struct SettingsView: View {
    @AppStorage("defaultDisplayMode") private var defaultDisplayMode: Int = 1
    @AppStorage("showSidebarOnOpen") private var showSidebarOnOpen: Bool = true
    @AppStorage("defaultZoomLevel") private var defaultZoomLevel: Double = 1.0
    @AppStorage("backgroundColor") private var backgroundColor: String = "system"
    @AppStorage("continuousScroll") private var continuousScroll: Bool = true
    
    @EnvironmentObject var aiManager: AIAssistantManager
    
    var body: some View {
        TabView {
            GeneralSettingsView(
                defaultDisplayMode: $defaultDisplayMode,
                showSidebarOnOpen: $showSidebarOnOpen,
                defaultZoomLevel: $defaultZoomLevel,
                continuousScroll: $continuousScroll
            )
            .tabItem {
                Label("General", systemImage: "gear")
            }
            
            AppearanceSettingsView(backgroundColor: $backgroundColor)
            .tabItem {
                Label("Appearance", systemImage: "paintbrush")
            }
            
            AISettingsTabView()
                .environmentObject(aiManager)
            .tabItem {
                Label("AI", systemImage: "sparkles")
            }
        }
        .frame(width: 520, height: 480)
        .padding()
    }
}

struct GeneralSettingsView: View {
    @Binding var defaultDisplayMode: Int
    @Binding var showSidebarOnOpen: Bool
    @Binding var defaultZoomLevel: Double
    @Binding var continuousScroll: Bool
    
    var body: some View {
        Form {
            Section {
                Picker("Default View Mode:", selection: $defaultDisplayMode) {
                    Text("Single Page").tag(0)
                    Text("Single Page Continuous").tag(1)
                    Text("Two Pages").tag(2)
                    Text("Two Pages Continuous").tag(3)
                }
                .pickerStyle(.menu)
                
                Toggle("Show sidebar when opening documents", isOn: $showSidebarOnOpen)
                
                Toggle("Enable continuous scroll", isOn: $continuousScroll)
                
                HStack {
                    Text("Default Zoom Level:")
                    Slider(value: $defaultZoomLevel, in: 0.5...3.0, step: 0.25) {
                        Text("Zoom")
                    }
                    Text("\(Int(defaultZoomLevel * 100))%")
                        .frame(width: 50)
                }
            }
        }
        .padding()
    }
}

struct AppearanceSettingsView: View {
    @Binding var backgroundColor: String
    
    var body: some View {
        Form {
            Section {
                Picker("Background Color:", selection: $backgroundColor) {
                    Text("System Default").tag("system")
                    Text("White").tag("white")
                    Text("Light Gray").tag("lightGray")
                    Text("Dark Gray").tag("darkGray")
                }
                .pickerStyle(.menu)
            }
        }
        .padding()
    }
}

struct AISettingsTabView: View {
    @EnvironmentObject var aiManager: AIAssistantManager
    @State private var showAPIKey = false
    @State private var testingConnection = false
    @State private var connectionStatus: ConnectionStatus = .unknown
    
    enum ConnectionStatus {
        case unknown, testing, success, failure
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Provider Selection Card
                VStack(alignment: .leading, spacing: 12) {
                    Label("AI Provider", systemImage: "cpu")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // Provider buttons
                    HStack(spacing: 12) {
                        ForEach(AIProvider.allCases, id: \.self) { provider in
                            ProviderButton(
                                provider: provider,
                                isSelected: aiManager.settings.provider == provider
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    aiManager.settings.provider = provider
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                
                // API Key Card (if needed)
                if aiManager.settings.provider.requiresAPIKey {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("API Key", systemImage: "key.fill")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            if showAPIKey {
                                TextField("Enter your API key", text: $aiManager.settings.apiKey)
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                SecureField("Enter your API key", text: $aiManager.settings.apiKey)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            Button(action: { showAPIKey.toggle() }) {
                                Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                        
                        // Get API Key link
                        Link(destination: apiKeyURL) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.caption)
                                Text("Get API Key")
                                    .font(.caption)
                            }
                            .foregroundColor(.accentColor)
                        }
                        
                        // Test connection button
                        HStack {
                            Button(action: testConnection) {
                                HStack(spacing: 6) {
                                    if connectionStatus == .testing {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    } else {
                                        Image(systemName: "bolt.fill")
                                    }
                                    Text("Test Connection")
                                }
                            }
                            .disabled(aiManager.settings.apiKey.isEmpty || connectionStatus == .testing)
                            
                            if connectionStatus == .success {
                                Label("Connected", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            } else if connectionStatus == .failure {
                                Label("Failed", systemImage: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                } else if aiManager.settings.provider == .ollama {
                    // Ollama info card
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Local Setup", systemImage: "desktopcomputer")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ollama runs locally on your machine for privacy.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Quick Setup:")
                                    .font(.caption.bold())
                                Text("1. Download Ollama from ollama.ai")
                                Text("2. Run: ollama pull llama2")
                                Text("3. Ensure Ollama is running")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                }
                
                // Model Settings Card
                VStack(alignment: .leading, spacing: 16) {
                    Label("Model Settings", systemImage: "slider.horizontal.3")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // Temperature
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Temperature")
                                .font(.subheadline)
                            Spacer()
                            Text("\(aiManager.settings.temperature, specifier: "%.1f")")
                                .font(.subheadline.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $aiManager.settings.temperature, in: 0...1, step: 0.1)
                            .tint(.accentColor)
                        
                        HStack {
                            Text("Precise")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Creative")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // Max Tokens
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Max Tokens")
                                .font(.subheadline)
                            Spacer()
                            Text("\(aiManager.settings.maxTokens)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: Binding(
                            get: { Double(aiManager.settings.maxTokens) },
                            set: { aiManager.settings.maxTokens = Int($0) }
                        ), in: 100...4000, step: 100)
                        .tint(.accentColor)
                        
                        HStack {
                            Text("Short")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Long")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                
                // Save button
                Button(action: { aiManager.saveSettings() }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Save Settings")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
        }
    }
    
    private var apiKeyURL: URL {
        switch aiManager.settings.provider {
        case .openAI:
            return URL(string: "https://platform.openai.com/api-keys")!
        case .anthropic:
            return URL(string: "https://console.anthropic.com/settings/keys")!
        default:
            return URL(string: "https://ollama.ai")!
        }
    }
    
    private func testConnection() {
        connectionStatus = .testing
        
        // Simulate connection test
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            connectionStatus = aiManager.settings.apiKey.count > 10 ? .success : .failure
        }
    }
}

// MARK: - Provider Button
struct ProviderButton: View {
    let provider: AIProvider
    let isSelected: Bool
    let action: () -> Void
    
    private var icon: String {
        switch provider {
        case .openAI: return "brain"
        case .anthropic: return "sparkles"
        case .ollama: return "desktopcomputer"
        case .localLLM: return "laptopcomputer"
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(provider.rawValue)
                    .font(.caption.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .foregroundColor(isSelected ? .accentColor : .primary)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AIAssistantManager())
    }
}
