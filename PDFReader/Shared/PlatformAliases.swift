//
//  PlatformAliases.swift
//  PDFReader
//
//  Cross-platform type aliases for macOS and iOS compatibility
//

import SwiftUI
import PDFKit

#if os(iOS)
import UIKit

// Type aliases for cross-platform compatibility
typealias PlatformColor = UIColor
typealias PlatformView = UIView
typealias PlatformViewController = UIViewController
typealias PlatformImage = UIImage
typealias PlatformFont = UIFont
typealias PlatformBezierPath = UIBezierPath
typealias PlatformViewRepresentable = UIViewRepresentable

extension UIColor {
    static var systemBackground: UIColor {
        return UIColor.systemBackground
    }
    
    static var textBackgroundColor: UIColor {
        return UIColor.systemBackground
    }
    
    static var separatorColor: UIColor {
        return UIColor.separator
    }
    
    static var controlBackgroundColor: UIColor {
        return UIColor.secondarySystemBackground
    }
}

#else
import AppKit

// Type aliases for cross-platform compatibility
typealias PlatformColor = NSColor
typealias PlatformView = NSView
typealias PlatformViewController = NSViewController
typealias PlatformImage = NSImage
typealias PlatformFont = NSFont
typealias PlatformBezierPath = NSBezierPath
typealias PlatformViewRepresentable = NSViewRepresentable

#endif

// MARK: - Cross-Platform SwiftUI Extensions

extension Color {
    #if os(iOS)
    static var systemBackground: Color {
        Color(UIColor.systemBackground)
    }
    
    static var secondarySystemBackground: Color {
        Color(UIColor.secondarySystemBackground)
    }
    
    static var tertiarySystemBackground: Color {
        Color(UIColor.tertiarySystemBackground)
    }
    #else
    static var systemBackground: Color {
        Color(NSColor.windowBackgroundColor)
    }
    
    static var secondarySystemBackground: Color {
        Color(NSColor.controlBackgroundColor)
    }
    
    static var tertiarySystemBackground: Color {
        Color(NSColor.underPageBackgroundColor)
    }
    #endif
}

// MARK: - Platform-Specific View Modifiers

struct PlatformAdaptiveModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .navigationBarTitleDisplayMode(.inline)
        #else
        content
        #endif
    }
}

extension View {
    func platformAdaptive() -> some View {
        modifier(PlatformAdaptiveModifier())
    }
}

// MARK: - Device Detection

enum DeviceType {
    case phone
    case tablet
    case mac
    
    static var current: DeviceType {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? .tablet : .phone
        #else
        return .mac
        #endif
    }
    
    var isCompact: Bool {
        return self == .phone
    }
}

// MARK: - Adaptive Layout

struct AdaptiveStack<Content: View>: View {
    let horizontalAlignment: HorizontalAlignment
    let verticalAlignment: VerticalAlignment
    let spacing: CGFloat?
    let content: () -> Content
    
    @Environment(\.horizontalSizeClass) var sizeClass
    
    init(
        horizontalAlignment: HorizontalAlignment = .center,
        verticalAlignment: VerticalAlignment = .center,
        spacing: CGFloat? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        Group {
            if sizeClass == .compact {
                VStack(alignment: horizontalAlignment, spacing: spacing, content: content)
            } else {
                HStack(alignment: verticalAlignment, spacing: spacing, content: content)
            }
        }
    }
}
