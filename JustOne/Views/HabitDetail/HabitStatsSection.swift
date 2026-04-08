//
//  HabitStatsSection.swift
//  JustOne
//
//  Statistics row showing streak, total completions, and weekly rate.
//

import SwiftUI

struct HabitStatsSection: View {
    let habit: Habit

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                statCard(title: "Streak",  value: "\(habit.currentStreak)", unit: "weeks",     icon: "flame.fill",                     color: .justWarning)
                statCard(title: "Total",   value: "\(habit.totalCompletions)", unit: "days",   icon: "calendar",                       color: habit.displayColor)
                statCard(title: "Rate",    value: "\(Int(habit.weeklyProgress() * 100))%", unit: "this week", icon: "chart.line.uptrend.xyaxis", color: .justSuccess)
            }

            if habit.currentStreak >= 4 {
                Text("You're building something. \(habit.currentStreak) weeks and counting.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else if habit.currentStreak >= 2 {
                Text("Consistency beats intensity. Keep showing up.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func statCard(title: String, value: String, unit: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .glassCard(cornerRadius: 16)
    }
}
