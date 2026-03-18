//
//  OCRManager.swift
//  PDFReader
//
//  OCR support for scanned PDFs using Vision framework
//

import Foundation
import PDFKit
import Vision
import AppKit

struct OCRResult: Identifiable {
    let id = UUID()
    let pageIndex: Int
    let text: String
    let confidence: Float
    let boundingBox: CGRect
}

class OCRManager: ObservableObject {
    static let shared = OCRManager()
    
    @Published var isProcessing = false
    @Published var progress: Double = 0
    @Published var currentPageText: String = ""
    @Published var ocrResults: [Int: [OCRResult]] = [:] // pageIndex -> results
    @Published var errorMessage: String?
    
    // Settings
    @Published var recognitionLevel: VNRequestTextRecognitionLevel = .accurate
    @Published var recognitionLanguages: [String] = ["en-US"]
    @Published var usesLanguageCorrection = true
    
    private var recognitionRequest: VNRecognizeTextRequest?
    
    private init() {}
    
    // MARK: - OCR Processing
    
    func performOCR(on document: PDFDocument, pageIndices: [Int]? = nil) async {
        await MainActor.run {
            isProcessing = true
            progress = 0
            ocrResults = [:]
            errorMessage = nil
        }
        
        let pagesToProcess = pageIndices ?? Array(0..<document.pageCount)
        let totalPages = pagesToProcess.count
        
        for (index, pageIndex) in pagesToProcess.enumerated() {
            guard let page = document.page(at: pageIndex) else { continue }
            
            await MainActor.run {
                progress = Double(index + 1) / Double(totalPages)
            }
            
            // Check if page already has text
            if let existingText = page.string, !existingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Page already has text, skip OCR
                continue
            }
            
            // Render page to image
            guard let image = renderPageToImage(page) else {
                continue
            }
            
            // Perform OCR
            let results = await recognizeText(in: image, pageIndex: pageIndex)
            
            await MainActor.run {
                ocrResults[pageIndex] = results
            }
        }
        
        await MainActor.run {
            isProcessing = false
            progress = 1.0
        }
    }
    
    func performOCROnCurrentPage(_ page: PDFPage, pageIndex: Int) async -> String {
        await MainActor.run {
            isProcessing = true
            currentPageText = ""
        }
        
        guard let image = renderPageToImage(page) else {
            await MainActor.run {
                isProcessing = false
                errorMessage = "Failed to render page"
            }
            return ""
        }
        
        let results = await recognizeText(in: image, pageIndex: pageIndex)
        let text = results.map { $0.text }.joined(separator: "\n")
        
        await MainActor.run {
            currentPageText = text
            ocrResults[pageIndex] = results
            isProcessing = false
        }
        
        return text
    }
    
    private func renderPageToImage(_ page: PDFPage) -> CGImage? {
        let pageRect = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0 // Higher resolution for better OCR
        
        let width = Int(pageRect.width * scale)
        let height = Int(pageRect.height * scale)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }
        
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        context.scaleBy(x: scale, y: scale)
        
        // Draw PDF page
        if let cgPage = page.pageRef {
            context.drawPDFPage(cgPage)
        }
        
        return context.makeImage()
    }
    
    private func recognizeText(in image: CGImage, pageIndex: Int) async -> [OCRResult] {
        return await withCheckedContinuation { continuation in
            var results: [OCRResult] = []
            
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first else { continue }
                    
                    let result = OCRResult(
                        pageIndex: pageIndex,
                        text: topCandidate.string,
                        confidence: topCandidate.confidence,
                        boundingBox: observation.boundingBox
                    )
                    results.append(result)
                }
                
                continuation.resume(returning: results)
            }
            
            request.recognitionLevel = recognitionLevel
            request.recognitionLanguages = recognitionLanguages
            request.usesLanguageCorrection = usesLanguageCorrection
            
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }
    
    // MARK: - Search in OCR Results
    
    func search(_ query: String) -> [(pageIndex: Int, result: OCRResult)] {
        var matches: [(pageIndex: Int, result: OCRResult)] = []
        let lowercaseQuery = query.lowercased()
        
        for (pageIndex, pageResults) in ocrResults {
            for result in pageResults {
                if result.text.lowercased().contains(lowercaseQuery) {
                    matches.append((pageIndex, result))
                }
            }
        }
        
        return matches.sorted { $0.pageIndex < $1.pageIndex }
    }
    
    // MARK: - Export
    
    func getFullText(for document: PDFDocument) -> String {
        var fullText = ""
        
        for pageIndex in 0..<document.pageCount {
            if let results = ocrResults[pageIndex] {
                fullText += "--- Page \(pageIndex + 1) ---\n"
                fullText += results.map { $0.text }.joined(separator: "\n")
                fullText += "\n\n"
            } else if let page = document.page(at: pageIndex), let text = page.string {
                fullText += "--- Page \(pageIndex + 1) ---\n"
                fullText += text
                fullText += "\n\n"
            }
        }
        
        return fullText
    }
    
    func exportOCRText(for document: PDFDocument) {
        let text = getFullText(for: document)
        
        let panel = NSSavePanel()
        panel.title = "Export OCR Text"
        panel.nameFieldStringValue = "ocr_output.txt"
        panel.allowedContentTypes = [.plainText]
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? text.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
    
    // MARK: - Settings
    
    func setRecognitionLevel(_ level: VNRequestTextRecognitionLevel) {
        recognitionLevel = level
    }
    
    func addLanguage(_ language: String) {
        if !recognitionLanguages.contains(language) {
            recognitionLanguages.append(language)
        }
    }
    
    func removeLanguage(_ language: String) {
        recognitionLanguages.removeAll { $0 == language }
    }
    
    static var supportedLanguages: [String] {
        return (try? VNRecognizeTextRequest().supportedRecognitionLanguages()) ?? ["en-US"]
    }
}
