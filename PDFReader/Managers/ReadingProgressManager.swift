//
//  ReadingProgressManager.swift
//  PDFReader
//
//  Tracks reading progress for documents
//

import Foundation
import Combine

struct ReadingSession: Codable, Identifiable {
    let id: UUID
    let documentName: String
    let startTime: Date
    var endTime: Date?
    var pagesRead: Set<Int>
    var totalReadingTime: TimeInterval
    
    init(documentName: String) {
        self.id = UUID()
        self.documentName = documentName
        self.startTime = Date()
        self.pagesRead = []
        self.totalReadingTime = 0
    }
}

struct DocumentProgress: Codable, Identifiable {
    var id: String { documentName }
    let documentName: String
    var totalPages: Int
    var pagesRead: Set<Int>
    var totalReadingTime: TimeInterval
    var lastReadDate: Date
    var sessions: [ReadingSession]
    
    var progressPercentage: Double {
        guard totalPages > 0 else { return 0 }
        return Double(pagesRead.count) / Double(totalPages) * 100
    }
    
    var formattedReadingTime: String {
        let hours = Int(totalReadingTime) / 3600
        let minutes = (Int(totalReadingTime) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

class ReadingProgressManager: ObservableObject {
    static let shared = ReadingProgressManager()
    
    @Published var documentProgress: [String: DocumentProgress] = [:]
    @Published var currentSession: ReadingSession?
    @Published var todayReadingTime: TimeInterval = 0
    @Published var weeklyReadingTime: TimeInterval = 0
    @Published var dailyGoalMinutes: Int = 30
    
    private var sessionTimer: Timer?
    private var currentPageStartTime: Date?
    private let storageKey = "readingProgress"
    private let sessionsKey = "readingSessions"
    
    private init() {
        loadProgress()
        calculateTodayTime()
    }
    
    // MARK: - Session Management
    
    func startSession(documentName: String, totalPages: Int) {
        // End any existing session
        endCurrentSession()
        
        // Start new session
        currentSession = ReadingSession(documentName: documentName)
        currentPageStartTime = Date()
        
        // Ensure document progress exists
        if documentProgress[documentName] == nil {
            documentProgress[documentName] = DocumentProgress(
                documentName: documentName,
                totalPages: totalPages,
                pagesRead: [],
                totalReadingTime: 0,
                lastReadDate: Date(),
                sessions: []
            )
        }
        
        // Update total pages if changed
        documentProgress[documentName]?.totalPages = totalPages
        
        // Start timer for tracking active reading
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateSessionTime()
        }
    }
    
    func endCurrentSession() {
        sessionTimer?.invalidate()
        sessionTimer = nil
        
        guard var session = currentSession else { return }
        session.endTime = Date()
        
        // Add session to document progress
        if var progress = documentProgress[session.documentName] {
            progress.sessions.append(session)
            progress.totalReadingTime += session.totalReadingTime
            progress.lastReadDate = Date()
            documentProgress[session.documentName] = progress
        }
        
        currentSession = nil
        currentPageStartTime = nil
        
        saveProgress()
        calculateTodayTime()
    }
    
    func markPageRead(_ pageIndex: Int) {
        guard let session = currentSession else { return }
        
        currentSession?.pagesRead.insert(pageIndex)
        
        if var progress = documentProgress[session.documentName] {
            progress.pagesRead.insert(pageIndex)
            progress.lastReadDate = Date()
            documentProgress[session.documentName] = progress
        }
    }
    
    private func updateSessionTime() {
        guard currentSession != nil else { return }
        currentSession?.totalReadingTime += 1
        todayReadingTime += 1
    }
    
    // MARK: - Statistics
    
    var dailyGoalProgress: Double {
        let goalSeconds = Double(dailyGoalMinutes * 60)
        guard goalSeconds > 0 else { return 0 }
        return min(todayReadingTime / goalSeconds, 1.0)
    }
    
    var streakDays: Int {
        // Calculate reading streak
        var streak = 0
        let calendar = Calendar.current
        var checkDate = Date()
        
        for _ in 0..<365 {
            let dayStart = calendar.startOfDay(for: checkDate)
            let hasReading = documentProgress.values.contains { progress in
                calendar.isDate(progress.lastReadDate, inSameDayAs: dayStart)
            }
            
            if hasReading {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else if streak > 0 {
                break
            } else {
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            }
        }
        
        return streak
    }
    
    private func calculateTodayTime() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        todayReadingTime = 0
        weeklyReadingTime = 0
        
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        
        for progress in documentProgress.values {
            for session in progress.sessions {
                if calendar.isDate(session.startTime, inSameDayAs: today) {
                    todayReadingTime += session.totalReadingTime
                }
                if session.startTime >= weekAgo {
                    weeklyReadingTime += session.totalReadingTime
                }
            }
        }
    }
    
    // MARK: - Persistence
    
    private func loadProgress() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: DocumentProgress].self, from: data) {
            documentProgress = decoded
        }
    }
    
    func saveProgress() {
        if let encoded = try? JSONEncoder().encode(documentProgress) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    func getProgress(for documentName: String) -> DocumentProgress? {
        return documentProgress[documentName]
    }
    
    func resetProgress(for documentName: String) {
        documentProgress.removeValue(forKey: documentName)
        saveProgress()
    }
}
