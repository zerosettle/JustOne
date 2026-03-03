//
//  BreakHabitExplainer.swift
//  JustOne
//
//  Inline callout explaining how "Break" (inverse) habits work.
//  Shown in AddHabitView and AddHabitWizardView when the user selects Break.
//

import SwiftUI

struct BreakHabitExplainer: View {
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("How breaking habits work", systemImage: "info.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(accentColor)

            VStack(alignment: .leading, spacing: 6) {
                bullet(icon: "checkmark.shield.fill", text: "Starts as completed each day — you're holding strong")
                bullet(icon: "xmark.circle.fill", text: "Tap to log a slip-up if you gave in")
                bullet(icon: "flame.fill", text: "Build streaks of consecutive clean days")
            }
        }
        .padding(16)
        .glassCard()
    }

    private func bullet(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 16)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
