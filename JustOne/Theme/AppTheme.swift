//
//  AppTheme.swift
//  JustOne
//
//  Defines the visual language: adaptive colors for light & dark mode,
//  glass-card modifier with improved contrast.
//

import SwiftUI
import UIKit

// MARK: - Adaptive Color Helper

extension Color {
    /// Creates a color that adapts to the current interface style (light/dark).
    static func adaptive(light: Color, dark: Color) -> Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}

// MARK: - Color Palette

extension Color {

    // Brand
    static let justPrimary = Color.adaptive(
        light: Color(red: 0.53, green: 0.45, blue: 0.93),
        dark: Color(red: 0.62, green: 0.54, blue: 0.98)
    )
    static let justSecondary = Color.adaptive(
        light: Color(red: 0.55, green: 0.71, blue: 0.98),
        dark: Color(red: 0.60, green: 0.76, blue: 1.0)
    )
    static let justAccent = Color.adaptive(
        light: Color(red: 0.69, green: 0.52, blue: 0.96),
        dark: Color(red: 0.76, green: 0.60, blue: 1.0)
    )

    // Backgrounds
    static let justBackground = Color.adaptive(
        light: Color(red: 0.95, green: 0.95, blue: 0.96),
        dark: Color(red: 0.0, green: 0.0, blue: 0.0)
    )
    static let justSurface = Color.adaptive(
        light: Color(red: 0.98, green: 0.98, blue: 0.99),
        dark: Color(red: 0.11, green: 0.11, blue: 0.11)
    )

    // Semantic
    static let justSuccess = Color.adaptive(
        light: Color(red: 0.40, green: 0.82, blue: 0.60),
        dark: Color(red: 0.45, green: 0.88, blue: 0.65)
    )
    static let justWarning = Color.adaptive(
        light: Color(red: 0.98, green: 0.75, blue: 0.35),
        dark: Color(red: 1.0, green: 0.80, blue: 0.40)
    )

    // Habit accent palette
    static let habitPurple = Color.adaptive(
        light: Color(red: 0.69, green: 0.52, blue: 0.96),
        dark: Color(red: 0.76, green: 0.60, blue: 1.0)
    )
    static let habitBlue = Color.adaptive(
        light: Color(red: 0.45, green: 0.62, blue: 0.98),
        dark: Color(red: 0.52, green: 0.70, blue: 1.0)
    )
    static let habitTeal = Color.adaptive(
        light: Color(red: 0.40, green: 0.78, blue: 0.80),
        dark: Color(red: 0.47, green: 0.85, blue: 0.87)
    )
    static let habitPink = Color.adaptive(
        light: Color(red: 0.93, green: 0.50, blue: 0.67),
        dark: Color(red: 0.98, green: 0.57, blue: 0.74)
    )
    static let habitOrange = Color.adaptive(
        light: Color(red: 0.96, green: 0.65, blue: 0.40),
        dark: Color(red: 1.0, green: 0.72, blue: 0.47)
    )
    static let habitGreen = Color.adaptive(
        light: Color(red: 0.45, green: 0.80, blue: 0.55),
        dark: Color(red: 0.52, green: 0.87, blue: 0.62)
    )
}

// MARK: - Color ↔ Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else { return nil }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Gradients

extension LinearGradient {

    /// Main app background — light neutral wash (light) / true black (dark)
    static let justBackground = LinearGradient(
        colors: [
            Color.adaptive(
                light: Color(red: 0.94, green: 0.94, blue: 0.96),
                dark: Color(red: 0.0, green: 0.0, blue: 0.0)
            ),
            Color.adaptive(
                light: Color(red: 0.96, green: 0.96, blue: 0.97),
                dark: Color(red: 0.03, green: 0.03, blue: 0.03)
            ),
            Color.adaptive(
                light: Color(red: 0.97, green: 0.97, blue: 0.98),
                dark: Color(red: 0.05, green: 0.05, blue: 0.05)
            )
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Mint/teal gradient for billing savings CTAs
    static let savingsGradient = LinearGradient(
        colors: [
            Color(red: 0.30, green: 0.80, blue: 0.65),
            Color(red: 0.25, green: 0.72, blue: 0.75)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Premium / CTA gradient
    static let premiumGradient = LinearGradient(
        colors: [
            Color(red: 0.53, green: 0.45, blue: 0.93),
            Color(red: 0.69, green: 0.52, blue: 0.96),
            Color(red: 0.55, green: 0.71, blue: 0.98)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Liquid Press Button Style

/// Tap feedback for list rows: subtle scale + darken on press, spring back on release.
struct LiquidPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .brightness(configuration.isPressed ? -0.1 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Glass Card Modifier

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(colorScheme == .dark
                        ? AnyShapeStyle(.thinMaterial)
                        : AnyShapeStyle(Color.white)
                    )
            )
            .shadow(
                color: colorScheme == .dark
                    ? Color.black.opacity(0.25)
                    : Color.black.opacity(0.08),
                radius: colorScheme == .dark ? 16 : 12,
                x: 0,
                y: 4
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Glass Effect Compatibility

/// Applies `.glassEffect` on iOS 26+, falls back to a tinted background on older versions.
struct GlassEffectModifier: ViewModifier {
    var tint: Color?
    var shape: GlassShape = .capsule

    enum GlassShape {
        case capsule, circle
    }

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            switch shape {
            case .capsule:
                if let tint {
                    content.glassEffect(.regular.tint(tint).interactive(), in: .capsule)
                } else {
                    content.glassEffect(.regular.interactive(), in: .capsule)
                }
            case .circle:
                if let tint {
                    content.glassEffect(.regular.tint(tint).interactive(), in: .circle)
                } else {
                    content.glassEffect(.regular.interactive(), in: .circle)
                }
            }
        } else {
            switch shape {
            case .capsule:
                content.background(tint?.opacity(0.15) ?? Color(.secondarySystemBackground), in: Capsule())
            case .circle:
                content.background(tint ?? Color(.secondarySystemBackground), in: Circle())
            }
        }
    }
}
