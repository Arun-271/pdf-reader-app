//
//  DictionaryManager.swift
//  PDFReader
//
//  Manages dictionary lookups for selected text
//

import SwiftUI
import NaturalLanguage

class DictionaryManager: ObservableObject {
    @Published var definition: DictionaryDefinition?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    struct DictionaryDefinition: Identifiable {
        let id = UUID()
        var word: String
        var definitions: [String]
        var partOfSpeech: String?
        var phonetic: String?
        var examples: [String]
    }
    
    func lookupWord(_ word: String) async {
        let cleanedWord = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard !cleanedWord.isEmpty else { return }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // First try the system dictionary
        if let systemDefinition = getSystemDefinition(for: cleanedWord) {
            await MainActor.run {
                definition = DictionaryDefinition(
                    word: cleanedWord,
                    definitions: [systemDefinition],
                    partOfSpeech: nil,
                    phonetic: nil,
                    examples: []
                )
                isLoading = false
            }
            return
        }
        
        // Fall back to online dictionary API
        do {
            let result = try await fetchOnlineDefinition(for: cleanedWord)
            await MainActor.run {
                definition = result
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Could not find definition for '\(cleanedWord)'"
                isLoading = false
            }
        }
    }
    
    private func getSystemDefinition(for word: String) -> String? {
        // Use macOS built-in dictionary
        let range = CFRangeMake(0, word.count)
        guard let definition = DCSCopyTextDefinition(nil, word as CFString, range) else {
            return nil
        }
        return definition.takeRetainedValue() as String
    }
    
    private func fetchOnlineDefinition(for word: String) async throws -> DictionaryDefinition {
        let urlString = "https://api.dictionaryapi.dev/api/v2/entries/en/\(word)"
        guard let url = URL(string: urlString) else {
            throw DictionaryError.invalidWord
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw DictionaryError.notFound
        }
        
        let entries = try JSONDecoder().decode([DictionaryAPIResponse].self, from: data)
        guard let entry = entries.first else {
            throw DictionaryError.notFound
        }
        
        var definitions: [String] = []
        var examples: [String] = []
        var partOfSpeech: String?
        
        for meaning in entry.meanings {
            if partOfSpeech == nil {
                partOfSpeech = meaning.partOfSpeech
            }
            for def in meaning.definitions.prefix(3) {
                definitions.append(def.definition)
                if let example = def.example {
                    examples.append(example)
                }
            }
        }
        
        return DictionaryDefinition(
            word: entry.word,
            definitions: definitions,
            partOfSpeech: partOfSpeech,
            phonetic: entry.phonetic,
            examples: examples
        )
    }
    
    func clear() {
        definition = nil
        errorMessage = nil
    }
}

// Dictionary API Response models
struct DictionaryAPIResponse: Codable {
    var word: String
    var phonetic: String?
    var meanings: [Meaning]
    
    struct Meaning: Codable {
        var partOfSpeech: String
        var definitions: [Definition]
    }
    
    struct Definition: Codable {
        var definition: String
        var example: String?
    }
}

enum DictionaryError: LocalizedError {
    case invalidWord
    case notFound
    
    var errorDescription: String? {
        switch self {
        case .invalidWord:
            return "Invalid word"
        case .notFound:
            return "Definition not found"
        }
    }
}
