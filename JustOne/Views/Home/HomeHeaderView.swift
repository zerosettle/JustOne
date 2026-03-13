//
//  HomeHeaderView.swift
//  JustOne
//
//  Dynamic greeting, progress summary pills, and subtitle
//  for the home dashboard.
//

import SwiftUI

struct HomeHeaderView: View {
    let user: User?
    let activeHabits: [Habit]
    @Binding var statsSheetMode: StatsSheetMode?

    private var firstName: String {
        let full = user?.displayName ?? "Friend"
        return full.components(separatedBy: " ").first ?? full
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case  5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default:      return "Good night"
        }
    }

    private var greetingSubtitle: String {
        guard !activeHabits.isEmpty else { return "Start your first habit today" }
        let remaining = activeHabits.filter { !$0.isCompleted(on: Date()) }.count
        if remaining == 0 {
            return "All done for today"
        } else if remaining == activeHabits.count {
            return "\(remaining) habit\(remaining == 1 ? "" : "s") to go today"
        } else {
            return "\(remaining) more to go today"
        }
    }

    // MARK: - Progress

    private var dailyProgress: (completed: Int, total: Int) {
        let total = activeHabits.count
        let completed = activeHabits.filter { $0.isCompleted(on: Date()) }.count
        return (completed, total)
    }

    private var weeklyProgress: (completed: Int, total: Int) {
        let total = activeHabits.reduce(0) { $0 + $1.frequencyPerWeek }
        let completed = activeHabits.reduce(0) { $0 + $1.completionsInWeek() }
        return (min(completed, total), total)
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(firstName)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text(greetingSubtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)

            if !activeHabits.isEmpty {
                progressSummary
                    .padding(.top, 8)
            }
        }
        .padding(.top, 12)
    }

    private var progressSummary: some View {
        let daily = dailyProgress
        let weekly = weeklyProgress
        let dailyPct = daily.total > 0 ? Int(Double(daily.completed) / Double(daily.total) * 100) : 0
        let weeklyPct = weekly.total > 0 ? Int(Double(weekly.completed) / Double(weekly.total) * 100) : 0

        return HStack(spacing: 12) {
            Button { statsSheetMode = .daily } label: {
                progressPill(label: "Today", value: "\(dailyPct)%", detail: "\(daily.completed)/\(daily.total)", filled: dailyPct == 100)
            }
            .buttonStyle(.plain)

            Button { statsSheetMode = .weekly } label: {
                progressPill(label: "This week", value: "\(weeklyPct)%", detail: "\(weekly.completed)/\(weekly.total)", filled: weeklyPct == 100)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private func progressPill(label: String, value: String, detail: String, filled: Bool) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundColor(filled ? .white : .primary)
            Text(label)
                .font(.caption)
                .foregroundColor(filled ? .white.opacity(0.8) : .secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .modifier(GlassEffectModifier(
            tint: filled ? Color.justSuccess : nil,
            shape: .capsule
        ))
    }
}
