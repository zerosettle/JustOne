//
//  HapticFeedback.swift
//  JustOne
//
//  Lightweight wrapper around UIImpactFeedbackGenerator for
//  concise haptic feedback calls throughout the app.
//

import UIKit

enum HapticFeedback {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
