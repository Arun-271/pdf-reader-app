//
//  SavedColorsManager.swift
//  PDFReader
//
//  Manages saved custom highlight colors
//

import AppKit
import SwiftUI

class SavedColorsManager: ObservableObject {
    static let shared = SavedColorsManager()
    
    private let key = "savedCustomHighlightColors"
    private let maxColors = 12
    
    @Published var colors: [NSColor] = []
    
    private init() {
        loadColors()
    }
    
    func loadColors() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? NSKeyedUnarchiver.unarchivedArrayOfObjects(ofClass: NSColor.self, from: data) else {
            colors = []
            return
        }
        colors = decoded
    }
    
    func saveColors() {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: colors, requiringSecureCoding: false) else {
            return
        }
        UserDefaults.standard.set(data, forKey: key)
    }
    
    func addColor(_ color: NSColor) {
        // Check if similar color already exists
        if !colors.contains(where: { $0.isApproximatelyEqual(to: color) }) {
            colors.insert(color, at: 0)
            if colors.count > maxColors {
                colors.removeLast()
            }
            saveColors()
        }
    }
    
    func removeColor(_ color: NSColor) {
        colors.removeAll { $0.isApproximatelyEqual(to: color) }
        saveColors()
    }
    
    func removeColorAt(_ index: Int) {
        guard index >= 0 && index < colors.count else { return }
        colors.remove(at: index)
        saveColors()
    }
}

// MARK: - Better Color Picker View
struct ImprovedColorPickerSheet: View {
    @Binding var selectedColor: NSColor
    @ObservedObject var savedColors = SavedColorsManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var pickedColor: Color
    
    private let presetColors: [NSColor] = [
        .systemYellow, .systemGreen, .systemBlue,
        .systemPink, .systemOrange, .systemPurple,
        .systemRed, .systemTeal, .systemIndigo,
        .systemBrown, .systemMint, .systemCyan
    ]
    
    init(selectedColor: Binding<NSColor>) {
        self._selectedColor = selectedColor
        self._pickedColor = State(initialValue: Color(selectedColor.wrappedValue))
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Choose Color")
                .font(.headline)
            
            // Color wheel
            ColorPicker("", selection: $pickedColor, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 200, height: 120)
            
            // Preview swatch
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("Preview")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(pickedColor)
                        .frame(width: 60, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                        )
                }
            }
            
            Divider()
            
            // Preset colors
            VStack(alignment: .leading, spacing: 8) {
                Text("Presets")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(32), spacing: 8), count: 6), spacing: 8) {
                    ForEach(presetColors, id: \.self) { color in
                        ColorSwatchButton(color: color, isSelected: false) {
                            pickedColor = Color(color)
                        }
                    }
                }
            }
            
            // Saved custom colors
            if !savedColors.colors.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Saved Colors")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(32), spacing: 8), count: 6), spacing: 8) {
                        ForEach(Array(savedColors.colors.enumerated()), id: \.offset) { index, color in
                            ColorSwatchButton(color: color, isSelected: false) {
                                pickedColor = Color(color)
                            }
                            .contextMenu {
                                Button("Remove", role: .destructive) {
                                    savedColors.removeColorAt(index)
                                }
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                
                Button("Save & Apply") {
                    let nsColor = NSColor(pickedColor)
                    savedColors.addColor(nsColor)
                    selectedColor = nsColor
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Apply") {
                    selectedColor = NSColor(pickedColor)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 320)
    }
}

struct ColorSwatchButton: View {
    let color: NSColor
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(color))
                .frame(width: 28, height: 28)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.primary : (isHovered ? Color.primary.opacity(0.5) : Color.clear), lineWidth: 2)
                        .padding(-1)
                )
                .scaleEffect(isHovered ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}
