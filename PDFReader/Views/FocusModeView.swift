//
//  FocusModeView.swift
//  PDFReader
//
//  Distraction-free reading mode
//

import SwiftUI
import PDFKit

struct FocusModeView: View {
    @EnvironmentObject var documentManager: DocumentManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var timerManager = FocusTimerManager.shared
    
    @State private var showControls = false
    @State private var controlsTimer: Timer?
    @State private var isFullScreen = false
    @State private var showTimer = true
    @State private var backgroundColor: Color = .black
    @State private var textBrightness: Double = 1.0
    
    var body: some View {
        ZStack {
            // Background
            backgroundColor
                .ignoresSafeArea()
            
            // PDF View
            if documentManager.pdfDocument != nil {
                FocusModePDFView()
                    .environmentObject(documentManager)
                    .brightness(textBrightness - 1)
            }
            
            // Overlay controls
            VStack {
                // Top bar (appears on hover)
                if showControls {
                    topControlBar
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Spacer()
                
                // Bottom bar with timer
                if showControls || showTimer {
                    bottomBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                showControls = hovering
            }
            
            // Auto-hide controls after delay
            controlsTimer?.invalidate()
            if hovering {
                controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                    withAnimation {
                        showControls = false
                    }
                }
            }
        }
        .onAppear {
            // Start reading session
            if let name = documentManager.fileURL?.lastPathComponent {
                ReadingProgressManager.shared.startSession(
                    documentName: name,
                    totalPages: documentManager.pageCount
                )
            }
        }
        .onDisappear {
            ReadingProgressManager.shared.endCurrentSession()
        }
    }
    
    private var topControlBar: some View {
        HStack(spacing: 16) {
            // Exit Focus Mode
            Button(action: { dismiss() }) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                    Text("Exit Focus Mode")
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Page indicator
            Text("\(documentManager.currentPageIndex + 1) / \(documentManager.pageCount)")
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
            
            Spacer()
            
            // Settings menu
            Menu {
                Button(action: { showTimer.toggle() }) {
                    Label(showTimer ? "Hide Timer" : "Show Timer", systemImage: "timer")
                }
                
                Divider()
                
                Menu("Background") {
                    Button("Black") { backgroundColor = .black }
                    Button("Dark Gray") { backgroundColor = Color(white: 0.15) }
                    Button("Sepia") { backgroundColor = Color(red: 0.96, green: 0.94, blue: 0.86) }
                    Button("Dark Blue") { backgroundColor = Color(red: 0.05, green: 0.1, blue: 0.15) }
                }
                
                Menu("Brightness") {
                    ForEach([0.6, 0.8, 1.0, 1.2], id: \.self) { value in
                        Button("\(Int(value * 100))%") { textBrightness = value }
                    }
                }
                
                Divider()
                
                Button(action: toggleFullScreen) {
                    Label(isFullScreen ? "Exit Full Screen" : "Full Screen", systemImage: "arrow.up.left.and.arrow.down.right")
                }
            } label: {
                Image(systemName: "gear")
                    .font(.caption)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
            }
            .menuStyle(.borderlessButton)
        }
        .padding()
        .foregroundColor(.white)
    }
    
    private var bottomBar: some View {
        HStack(spacing: 20) {
            // Navigation
            HStack(spacing: 12) {
                Button(action: { documentManager.previousPage() }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(documentManager.currentPageIndex <= 0)
                
                Button(action: { documentManager.nextPage() }) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(documentManager.currentPageIndex >= documentManager.pageCount - 1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            
            // Timer (if enabled)
            if showTimer {
                HStack(spacing: 12) {
                    // Progress ring
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 3)
                        Circle()
                            .trim(from: 0, to: timerManager.progress)
                            .stroke(Color(timerManager.mode.color), lineWidth: 3)
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 28, height: 28)
                    
                    // Time
                    Text(timerManager.formattedTimeRemaining)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                    
                    // Control
                    Button(action: {
                        if timerManager.state == .running {
                            timerManager.pause()
                        } else {
                            timerManager.start()
                        }
                    }) {
                        Image(systemName: timerManager.state == .running ? "pause.fill" : "play.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
            }
            
            // Reading progress
            if let progress = ReadingProgressManager.shared.getProgress(for: documentManager.fileName) {
                HStack(spacing: 8) {
                    Image(systemName: "book")
                        .font(.caption)
                    Text("\(Int(progress.progressPercentage))%")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
            }
        }
        .foregroundColor(.white)
        .padding(.bottom, 40)
    }
    
    private func toggleFullScreen() {
        #if os(macOS)
        if let window = NSApplication.shared.windows.first {
            window.toggleFullScreen(nil)
            isFullScreen.toggle()
        }
        #endif
    }
}

// Simplified PDF View for focus mode
struct FocusModePDFView: PlatformViewRepresentable {
    @EnvironmentObject var documentManager: DocumentManager
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: FocusModePDFView
        
        init(_ parent: FocusModePDFView) {
            self.parent = parent
        }
        
        @objc func pageChanged(_ notification: Notification) {
            if let pdfView = notification.object as? PDFView,
               let page = pdfView.currentPage,
               let document = pdfView.document {
                let index = document.index(for: page)
                DispatchQueue.main.async {
                    if self.parent.documentManager.currentPageIndex != index {
                        self.parent.documentManager.currentPageIndex = index
                    }
                }
            }
        }
    }
    
    #if os(macOS)
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .horizontal
        pdfView.backgroundColor = .clear
        pdfView.displaysPageBreaks = false
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.pageChanged(_:)), name: .PDFViewPageChanged, object: pdfView)
        return pdfView
    }
    
    func updateNSView(_ pdfView: PDFView, context: Context) {
        updatePDFView(pdfView)
    }
    #else
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .horizontal
        pdfView.backgroundColor = .clear
        pdfView.displaysPageBreaks = false
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.pageChanged(_:)), name: .PDFViewPageChanged, object: pdfView)
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        updatePDFView(pdfView)
    }
    #endif
    
    private func updatePDFView(_ pdfView: PDFView) {
        if pdfView.document !== documentManager.pdfDocument {
            pdfView.document = documentManager.pdfDocument
        }
        if let current = pdfView.currentPage, let doc = pdfView.document {
            if doc.index(for: current) != documentManager.currentPageIndex {
                if let page = doc.page(at: documentManager.currentPageIndex) {
                    pdfView.go(to: page)
                }
            }
        } else if let page = documentManager.pdfDocument?.page(at: documentManager.currentPageIndex) {
            pdfView.go(to: page)
        }
    }
}

// MARK: - Focus Mode Toggle in Right Panel
struct FocusModeButton: View {
    @State private var showFocusMode = false
    
    var body: some View {
        Button(action: { showFocusMode = true }) {
            HStack(spacing: 8) {
                Image(systemName: "eye")
                Text("Focus Mode")
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showFocusMode) {
            FocusModeView()
                .frame(minWidth: 800, minHeight: 600)
        }
    }
}
