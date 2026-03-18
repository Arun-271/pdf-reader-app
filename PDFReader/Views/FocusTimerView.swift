//
//  FocusTimerView.swift
//  PDFReader
//
//  Pomodoro-style focus timer UI
//

import SwiftUI

struct FocusTimerView: View {
    @StateObject private var timerManager = FocusTimerManager.shared
    @State private var showSettings = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Timer display
            timerCircle
            
            // Mode selector
            modeSelector
            
            // Controls
            controlButtons
            
            Divider()
                .padding(.vertical, 8)
            
            // Stats
            statsSection
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showSettings) {
            FocusTimerSettingsView()
        }
    }
    
    private var timerCircle: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: timerManager.progress)
                .stroke(
                    Color(timerManager.mode.color),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: timerManager.progress)
            
            // Timer text
            VStack(spacing: 4) {
                Text(timerManager.formattedTimeRemaining)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                
                Text(timerManager.mode.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 160, height: 160)
    }
    
    private var modeSelector: some View {
        HStack(spacing: 8) {
            ForEach([TimerMode.pomodoro, .shortBreak, .longBreak], id: \.self) { mode in
                Button(action: {
                    if timerManager.state == .idle {
                        timerManager.setMode(mode)
                    }
                }) {
                    Text(mode.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(timerManager.mode == mode ? Color(mode.color).opacity(0.2) : Color.clear)
                        )
                        .foregroundColor(timerManager.mode == mode ? Color(mode.color) : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(timerManager.state != .idle)
            }
        }
    }
    
    private var controlButtons: some View {
        HStack(spacing: 16) {
            // Settings
            Button(action: { showSettings = true }) {
                Image(systemName: "gear")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            
            // Main control
            Button(action: {
                switch timerManager.state {
                case .idle:
                    timerManager.start()
                case .running:
                    timerManager.pause()
                case .paused:
                    timerManager.resume()
                case .breakTime:
                    timerManager.start()
                }
            }) {
                Image(systemName: timerManager.state == .running ? "pause.fill" : "play.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color(timerManager.mode.color)))
            }
            .buttonStyle(.plain)
            
            // Stop/Skip
            Button(action: {
                if timerManager.state == .running || timerManager.state == .paused {
                    timerManager.stop()
                } else {
                    timerManager.skip()
                }
            }) {
                Image(systemName: timerManager.state == .idle ? "forward.fill" : "stop.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(timerManager.state == .idle && timerManager.completedPomodoros == 0)
        }
    }
    
    private var statsSection: some View {
        VStack(spacing: 12) {
            HStack {
                StatItem(icon: "🍅", value: "\(timerManager.todayPomodoros)", label: "Today")
                Spacer()
                StatItem(icon: "🔥", value: "\(timerManager.completedPomodoros)", label: "Session")
            }
            
            // Focus time today
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                Text("Focus time: \(formattedFocusTime)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondarySystemBackground)
        )
    }
    
    private var formattedFocusTime: String {
        let minutes = Int(timerManager.totalFocusTime) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        }
        return "\(minutes)m"
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(icon)
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct FocusTimerSettingsView: View {
    @StateObject private var timerManager = FocusTimerManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var pomodoroText: String = ""
    @State private var shortBreakText: String = ""
    @State private var longBreakText: String = ""
    @State private var longBreakIntervalText: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Timer Settings")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Duration Settings
                    VStack(alignment: .leading, spacing: 16) {
                        Text("DURATION (MINUTES)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fontWeight(.semibold)
                        
                        // Pomodoro duration
                        DurationInputRow(
                            icon: "🍅",
                            label: "Focus",
                            value: $pomodoroText,
                            color: .red
                        )
                        
                        // Short break
                        DurationInputRow(
                            icon: "☕",
                            label: "Short Break",
                            value: $shortBreakText,
                            color: .green
                        )
                        
                        // Long break
                        DurationInputRow(
                            icon: "🏖️",
                            label: "Long Break",
                            value: $longBreakText,
                            color: .blue
                        )
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondarySystemBackground)
                    )
                    
                    // Automation Settings
                    VStack(alignment: .leading, spacing: 16) {
                        Text("AUTOMATION")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fontWeight(.semibold)
                        
                        // Long break interval
                        HStack {
                            Image(systemName: "repeat")
                                .foregroundColor(.orange)
                            Text("Long break after")
                            
                            TextField("", text: $longBreakIntervalText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 50)
                                .multilineTextAlignment(.center)
                            
                            Text("pomodoros")
                                .foregroundColor(.secondary)
                        }
                        .font(.system(size: 13))
                        
                        Divider()
                        
                        Toggle(isOn: $timerManager.autoStartBreaks) {
                            HStack {
                                Image(systemName: "play.circle")
                                    .foregroundColor(.green)
                                Text("Auto-start breaks")
                            }
                        }
                        .toggleStyle(.switch)
                        
                        Toggle(isOn: $timerManager.autoStartPomodoros) {
                            HStack {
                                Image(systemName: "arrow.clockwise.circle")
                                    .foregroundColor(.blue)
                                Text("Auto-start next focus session")
                            }
                        }
                        .toggleStyle(.switch)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondarySystemBackground)
                    )
                    
                    // Sound Settings
                    VStack(alignment: .leading, spacing: 12) {
                        Text("NOTIFICATIONS")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fontWeight(.semibold)
                        
                        Toggle(isOn: $timerManager.soundEnabled) {
                            HStack {
                                Image(systemName: "speaker.wave.2")
                                    .foregroundColor(.purple)
                                Text("Play sound when timer completes")
                            }
                        }
                        .toggleStyle(.switch)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondarySystemBackground)
                    )
                }
                .padding()
            }
            
            Divider()
            
            // Buttons
            HStack(spacing: 12) {
                Button("Reset to Defaults") {
                    resetToDefaults()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Save") {
                    saveSettings()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 380, height: 520)
        .onAppear {
            loadCurrentValues()
        }
    }
    
    private func loadCurrentValues() {
        pomodoroText = "\(timerManager.pomodoroMinutes)"
        shortBreakText = "\(timerManager.shortBreakMinutes)"
        longBreakText = "\(timerManager.longBreakMinutes)"
        longBreakIntervalText = "\(timerManager.pomodorosUntilLongBreak)"
    }
    
    private func saveSettings() {
        if let value = Int(pomodoroText), value > 0 && value <= 120 {
            timerManager.pomodoroMinutes = value
        }
        if let value = Int(shortBreakText), value > 0 && value <= 60 {
            timerManager.shortBreakMinutes = value
        }
        if let value = Int(longBreakText), value > 0 && value <= 60 {
            timerManager.longBreakMinutes = value
        }
        if let value = Int(longBreakIntervalText), value >= 2 && value <= 10 {
            timerManager.pomodorosUntilLongBreak = value
        }
        timerManager.saveSettings()
    }
    
    private func resetToDefaults() {
        pomodoroText = "25"
        shortBreakText = "5"
        longBreakText = "15"
        longBreakIntervalText = "4"
        timerManager.autoStartBreaks = true
        timerManager.autoStartPomodoros = false
        timerManager.soundEnabled = true
    }
}

struct DurationInputRow: View {
    let icon: String
    let label: String
    @Binding var value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(icon)
                .font(.title2)
            
            Text(label)
                .font(.system(size: 13, weight: .medium))
            
            Spacer()
            
            HStack(spacing: 4) {
                TextField("", text: $value)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .frame(width: 40)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(color.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
                
                Text("min")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Compact Timer (for toolbar/sidebar)
struct CompactFocusTimer: View {
    @StateObject private var timerManager = FocusTimerManager.shared
    
    var body: some View {
        HStack(spacing: 8) {
            // Mini progress ring
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: timerManager.progress)
                    .stroke(Color(timerManager.mode.color), lineWidth: 3)
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 24, height: 24)
            
            // Time
            Text(timerManager.formattedTimeRemaining)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
            
            // Control
            Button(action: {
                if timerManager.state == .running {
                    timerManager.pause()
                } else {
                    timerManager.start()
                }
            }) {
                Image(systemName: timerManager.state == .running ? "pause.fill" : "play.fill")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondarySystemBackground)
        )
    }
}
