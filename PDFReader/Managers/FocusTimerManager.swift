//
//  FocusTimerManager.swift
//  PDFReader
//
//  Pomodoro-style focus timer for reading sessions
//

import Foundation
import Combine
import AppKit

enum TimerState {
    case idle
    case running
    case paused
    case breakTime
}

enum TimerMode: String, CaseIterable {
    case pomodoro = "Pomodoro"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"
    case custom = "Custom"
    
    var defaultMinutes: Int {
        switch self {
        case .pomodoro: return 25
        case .shortBreak: return 5
        case .longBreak: return 15
        case .custom: return 30
        }
    }
    
    var color: PlatformColor {
        switch self {
        case .pomodoro: return .systemRed
        case .shortBreak: return .systemGreen
        case .longBreak: return .systemBlue
        case .custom: return .systemOrange
        }
    }
}

class FocusTimerManager: ObservableObject {
    static let shared = FocusTimerManager()
    
    // Timer state
    @Published var state: TimerState = .idle
    @Published var mode: TimerMode = .pomodoro
    @Published var timeRemaining: TimeInterval = 25 * 60
    @Published var totalTime: TimeInterval = 25 * 60
    
    // Session tracking
    @Published var completedPomodoros: Int = 0
    @Published var todayPomodoros: Int = 0
    @Published var totalFocusTime: TimeInterval = 0
    
    // Settings
    @Published var pomodoroMinutes: Int = 25
    @Published var shortBreakMinutes: Int = 5
    @Published var longBreakMinutes: Int = 15
    @Published var pomodorosUntilLongBreak: Int = 4
    @Published var autoStartBreaks: Bool = true
    @Published var autoStartPomodoros: Bool = false
    @Published var soundEnabled: Bool = true
    
    private var timer: Timer?
    private var sessionStartTime: Date?
    
    private init() {
        loadSettings()
        loadTodayStats()
    }
    
    // MARK: - Timer Controls
    
    func start() {
        guard state != .running else { return }
        
        if state == .idle {
            timeRemaining = totalTime
        }
        
        state = .running
        sessionStartTime = Date()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    func pause() {
        guard state == .running else { return }
        state = .paused
        timer?.invalidate()
        timer = nil
    }
    
    func resume() {
        guard state == .paused else { return }
        start()
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        state = .idle
        resetTimer()
    }
    
    func skip() {
        timer?.invalidate()
        timer = nil
        completeSession()
    }
    
    private func tick() {
        guard timeRemaining > 0 else {
            completeSession()
            return
        }
        
        timeRemaining -= 1
        
        if mode == .pomodoro {
            totalFocusTime += 1
        }
    }
    
    private func completeSession() {
        timer?.invalidate()
        timer = nil
        
        if soundEnabled {
            playCompletionSound()
        }
        
        showNotification()
        
        if mode == .pomodoro {
            completedPomodoros += 1
            todayPomodoros += 1
            saveTodayStats()
            
            // Determine next break type
            if completedPomodoros % pomodorosUntilLongBreak == 0 {
                setMode(.longBreak)
            } else {
                setMode(.shortBreak)
            }
            
            if autoStartBreaks {
                start()
            } else {
                state = .idle
            }
        } else {
            // Break is over, switch to pomodoro
            setMode(.pomodoro)
            
            if autoStartPomodoros {
                start()
            } else {
                state = .idle
            }
        }
    }
    
    func setMode(_ newMode: TimerMode) {
        mode = newMode
        resetTimer()
    }
    
    private func resetTimer() {
        let minutes: Int
        switch mode {
        case .pomodoro: minutes = pomodoroMinutes
        case .shortBreak: minutes = shortBreakMinutes
        case .longBreak: minutes = longBreakMinutes
        case .custom: minutes = pomodoroMinutes
        }
        
        totalTime = TimeInterval(minutes * 60)
        timeRemaining = totalTime
    }
    
    // MARK: - Formatting
    
    var formattedTimeRemaining: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var progress: Double {
        guard totalTime > 0 else { return 0 }
        return 1.0 - (timeRemaining / totalTime)
    }
    
    // MARK: - Notifications
    
    private func showNotification() {
        let notification = NSUserNotification()
        
        if mode == .pomodoro {
            notification.title = "Pomodoro Complete! 🍅"
            notification.informativeText = "Great work! Take a break."
        } else {
            notification.title = "Break Over!"
            notification.informativeText = "Ready for another focus session?"
        }
        
        notification.soundName = soundEnabled ? NSUserNotificationDefaultSoundName : nil
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    private func playCompletionSound() {
        NSSound(named: "Glass")?.play()
    }
    
    // MARK: - Persistence
    
    private func loadSettings() {
        let defaults = UserDefaults.standard
        pomodoroMinutes = defaults.integer(forKey: "pomodoroMinutes") > 0 ? defaults.integer(forKey: "pomodoroMinutes") : 25
        shortBreakMinutes = defaults.integer(forKey: "shortBreakMinutes") > 0 ? defaults.integer(forKey: "shortBreakMinutes") : 5
        longBreakMinutes = defaults.integer(forKey: "longBreakMinutes") > 0 ? defaults.integer(forKey: "longBreakMinutes") : 15
        autoStartBreaks = defaults.bool(forKey: "autoStartBreaks")
        autoStartPomodoros = defaults.bool(forKey: "autoStartPomodoros")
        soundEnabled = defaults.object(forKey: "timerSoundEnabled") as? Bool ?? true
        
        resetTimer()
    }
    
    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(pomodoroMinutes, forKey: "pomodoroMinutes")
        defaults.set(shortBreakMinutes, forKey: "shortBreakMinutes")
        defaults.set(longBreakMinutes, forKey: "longBreakMinutes")
        defaults.set(autoStartBreaks, forKey: "autoStartBreaks")
        defaults.set(autoStartPomodoros, forKey: "autoStartPomodoros")
        defaults.set(soundEnabled, forKey: "timerSoundEnabled")
    }
    
    private func loadTodayStats() {
        let defaults = UserDefaults.standard
        let lastDate = defaults.object(forKey: "lastPomodoroDate") as? Date ?? Date.distantPast
        
        if Calendar.current.isDateInToday(lastDate) {
            todayPomodoros = defaults.integer(forKey: "todayPomodoros")
        } else {
            todayPomodoros = 0
        }
    }
    
    private func saveTodayStats() {
        let defaults = UserDefaults.standard
        defaults.set(todayPomodoros, forKey: "todayPomodoros")
        defaults.set(Date(), forKey: "lastPomodoroDate")
    }
}
