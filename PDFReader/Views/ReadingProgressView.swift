//
//  ReadingProgressView.swift
//  PDFReader
//
//  Shows reading progress and statistics
//

import SwiftUI

struct ReadingProgressView: View {
    @EnvironmentObject var documentManager: DocumentManager
    @StateObject private var progressManager = ReadingProgressManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("", selection: $selectedTab) {
                Text("Current").tag(0)
                Text("Stats").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            
            if selectedTab == 0 {
                currentDocumentProgress
            } else {
                overallStatistics
            }
        }
    }
    
    private var currentDocumentProgress: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let progress = progressManager.getProgress(for: documentManager.fileName) {
                    // Progress ring
                    progressRing(progress: progress.progressPercentage / 100)
                    
                    // Stats grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(
                            title: "Pages Read",
                            value: "\(progress.pagesRead.count)",
                            subtitle: "of \(progress.totalPages)",
                            icon: "book.pages",
                            color: .blue
                        )
                        
                        StatCard(
                            title: "Time Spent",
                            value: progress.formattedReadingTime,
                            subtitle: "reading",
                            icon: "clock",
                            color: .green
                        )
                        
                        StatCard(
                            title: "Sessions",
                            value: "\(progress.sessions.count)",
                            subtitle: "total",
                            icon: "calendar",
                            color: .orange
                        )
                        
                        StatCard(
                            title: "Last Read",
                            value: formatDate(progress.lastReadDate),
                            subtitle: "",
                            icon: "clock.arrow.circlepath",
                            color: .purple
                        )
                    }
                    .padding(.horizontal)
                    
                    // Daily goal
                    dailyGoalSection
                    
                } else {
                    emptyState
                }
            }
            .padding()
        }
    }
    
    private func progressRing(progress: Double) -> some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 12)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(), value: progress)
            
            VStack(spacing: 4) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 140, height: 140)
    }
    
    private var dailyGoalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Daily Goal")
                    .font(.headline)
                Spacer()
                Text("\(Int(progressManager.todayReadingTime / 60))m / \(progressManager.dailyGoalMinutes)m")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.green, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progressManager.dailyGoalProgress)
                        .animation(.spring(), value: progressManager.dailyGoalProgress)
                }
            }
            .frame(height: 8)
            
            if progressManager.streakDays > 0 {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("\(progressManager.streakDays) day streak!")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondarySystemBackground)
        )
        .padding(.horizontal)
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No progress yet")
                .foregroundColor(.secondary)
            Text("Start reading to track your progress")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var overallStatistics: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Weekly summary
                weeklySummaryCard
                
                // All documents
                VStack(alignment: .leading, spacing: 8) {
                    Text("All Documents")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(Array(progressManager.documentProgress.values).sorted(by: { $0.lastReadDate > $1.lastReadDate })) { progress in
                        DocumentProgressRow(progress: progress)
                    }
                }
            }
            .padding()
        }
    }
    
    private var weeklySummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.headline)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text(formatTime(progressManager.weeklyReadingTime))
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Reading time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .frame(height: 40)
                
                VStack(alignment: .leading) {
                    Text("\(progressManager.documentProgress.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Documents")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .frame(height: 40)
                
                VStack(alignment: .leading) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("\(progressManager.streakDays)")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    Text("Day streak")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondarySystemBackground)
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondarySystemBackground)
        )
    }
}

struct DocumentProgressRow: View {
    let progress: DocumentProgress
    
    var body: some View {
        HStack(spacing: 12) {
            // Progress indicator
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: progress.progressPercentage / 100)
                    .stroke(Color.blue, lineWidth: 3)
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 36, height: 36)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(progress.documentName)
                    .font(.system(size: 13))
                    .lineLimit(1)
                
                Text("\(progress.pagesRead.count)/\(progress.totalPages) pages • \(progress.formattedReadingTime)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(Int(progress.progressPercentage))%")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondarySystemBackground.opacity(0.5))
        )
        .padding(.horizontal)
    }
}
