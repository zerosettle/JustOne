//
//  HabitRowView.swift
//  JustOne
//
//  Glass-card row shown in the home dashboard for each habit.
//  Displays the icon, name, a 14-day mini heatmap, and a
//  tappable check circle for frictionless daily logging.
//

import SwiftUI

struct HabitRowView: View {
    let habit: Habit
    var onToggleToday: () -> Void = {}

    private let today = Date()

    var body: some View {
        HStack(spacing: 16) {
            // Icon badge
            Image(systemName: habit.icon)
                .font(.title2)
                .foregroundColor(habit.accentColor.color)
                .frame(width: 48, height: 48)
                .background(
                    habit.accentColor.color.opacity(0.15),
                    in: RoundedRectangle(cornerRadius: 14)
                )

            // Name, goal subtitle & mini heatmap
            VStack(alignment: .leading, spacing: 6) {
                Text(habit.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                if habit.status == .paused {
                    Text("Paused")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if habit.isInverse {
                    let slips = habit.slipCount()
                    Text("\(slips) slip-up\(slips == 1 ? "" : "s") this week")
                        .font(.caption)
                        .foregroundColor(slips > 0 ? .justWarning : .justSuccess)
                } else if let config = habit.journeyConfig {
                    Text("Current: \(config.formattedValue(config.currentTarget))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(habit.frequencyPerWeek)\u{00D7} per week")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                miniHeatmap
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Quick check-in
            if habit.status != .paused {
                Button {
                    onToggleToday()
                } label: {
                    Image(systemName: toggleIconName)
                        .font(.system(size: 28))
                        .foregroundColor(toggleIconColor)
                }
                .buttonStyle(.borderless)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary.opacity(0.3))
        }
        .padding(16)
        .glassCard()
        .opacity(habit.status == .paused ? 0.55 : 1.0)
    }

    // MARK: - Toggle Icon

    private var toggleIconName: String {
        if habit.isInverse {
            // Inverse: completed means "holding strong", uncompleted means "slipped"
            return habit.isCompleted(on: today) ? "checkmark.shield.fill" : "xmark.circle.fill"
        }
        return habit.isCompleted(on: today) ? "checkmark.circle.fill" : "circle"
    }

    private var toggleIconColor: Color {
        if habit.isInverse {
            return habit.isCompleted(on: today) ? .justSuccess : .justWarning
        }
        return habit.isCompleted(on: today) ? habit.accentColor.color : .secondary.opacity(0.3)
    }

    // MARK: - Mini Heatmap (14 days)

    private var miniHeatmap: some View {
        HStack(spacing: 3) {
            ForEach(0..<14, id: \.self) { i in
                let date = Calendar.current.date(byAdding: .day, value: -(13 - i), to: today)!
                let isCompleted = habit.isCompleted(on: date)
                Circle()
                    .fill(miniHeatmapColor(date: date, isCompleted: isCompleted))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private func miniHeatmapColor(date: Date, isCompleted: Bool) -> Color {
        if habit.isInverse {
            // Inverse: green for clean days, warning for slip-ups
            return isCompleted
                ? Color.justSuccess.opacity(0.5)
                : Color.justWarning.opacity(0.7)
        }
        guard isCompleted else {
            return habit.accentColor.color.opacity(0.12)
        }
        if let config = habit.journeyConfig {
            let intensity = config.levelIntensity(on: Habit.dateKey(for: date))
            return habit.accentColor.color.opacity(0.4 + intensity * 0.6)
        }
        return habit.accentColor.color
    }
}
