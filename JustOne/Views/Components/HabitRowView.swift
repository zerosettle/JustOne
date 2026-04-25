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
    var isLocked: Bool = false
    var isNextUp: Bool = false
    var onToggleToday: () -> Void = {}
    var onAffirmToday: (() -> Void)? = nil
    var onSlipToday: (() -> Void)? = nil

    private let today = Date()

    private var isAutoCompletedToday: Bool {
        habit.isAutoCompleted(on: today)
    }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: habit.icon)
                .font(.title2)
                .foregroundColor(habit.displayColor)
                .frame(width: 48, height: 48)
                .background(
                    habit.displayColor.opacity(0.15),
                    in: RoundedRectangle(cornerRadius: 14)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(habit.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                if habit.status == .paused {
                    Text("Paused")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if isAutoCompletedToday {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundColor(.pink)
                        Text("Auto-logged")
                            .font(.caption)
                            .foregroundColor(.pink)
                    }
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

            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.secondary.opacity(0.4))
            } else if habit.status != .paused {
                if habit.isInverse && habit.status == .active {
                    inverseActionArea
                } else {
                    Button {
                        onToggleToday()
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            Image(systemName: toggleIconName)
                                .font(.system(size: 28))
                                .foregroundColor(toggleIconColor)

                            if isAutoCompletedToday {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.pink)
                                    .offset(x: 2, y: 2)
                            }
                        }
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(habit.isCompleted(on: today)
                        ? "Mark \(habit.name) incomplete"
                        : "Mark \(habit.name) complete"
                    )
                    .accessibilityHint(habit.isCompleted(on: today)
                        ? "Double tap to unmark as complete"
                        : "Double tap to mark as complete"
                    )
                    .accessibilityValue(habit.isCompleted(on: today) ? "Completed" : "Not completed")
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary.opacity(0.3))
        }
        .padding(16)
        .glassCard()
        .overlay {
            if isNextUp {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(habit.displayColor.opacity(0.3), lineWidth: 1)
                    RoundedRectangle(cornerRadius: 20)
                        .fill(habit.displayColor)
                        .frame(width: 4)
                }
            }
        }
        .opacity(isLocked || habit.status == .paused ? 0.55 : 1.0)
    }

    // MARK: - Inverse Action Area

    @ViewBuilder
    private var inverseActionArea: some View {
        let affirmed = habit.isAffirmed(on: today)
        let slipped = !habit.isCompleted(on: today) // isCompleted inverts for inverse, so !completed = slipped

        if affirmed {
            // Affirmed state — tap to undo
            Button { onAffirmToday?() } label: {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.justSuccess)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("\(habit.name), affirmed today")
            .accessibilityHint("Double tap to undo")
        } else if slipped {
            // Slipped state — tap to undo
            Button { onSlipToday?() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.justWarning)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("\(habit.name), slip logged today")
            .accessibilityHint("Double tap to undo")
        } else {
            // Not interacted — show side-by-side buttons
            HStack(spacing: 8) {
                Button { onSlipToday?() } label: {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 22))
                        .foregroundColor(.secondary.opacity(0.4))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Log slip for \(habit.name)")
                .accessibilityHint("Double tap to record a slip-up today")

                Button { onAffirmToday?() } label: {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.justSuccess)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Affirm \(habit.name)")
                .accessibilityHint("Double tap to mark today as clean")
            }
        }
    }

    // MARK: - Toggle Icon (non-inverse only)

    private var toggleIconName: String {
        return habit.isCompleted(on: today) ? "checkmark.circle.fill" : "circle"
    }

    private var toggleIconColor: Color {
        return habit.isCompleted(on: today) ? habit.displayColor : .secondary.opacity(0.3)
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
            let slipped = !isCompleted  // isCompleted inverts for inverse
            let affirmed = habit.isAffirmed(on: date)
            if affirmed {
                return Color.justSuccess               // bright green — actively checked in
            } else if slipped {
                return Color.justWarning.opacity(0.7)  // warning — slipped
            } else {
                return Color.justSuccess.opacity(0.25) // dim — passive clean day
            }
        }
        guard isCompleted else {
            return habit.displayColor.opacity(0.12)
        }
        if let config = habit.journeyConfig {
            let intensity = config.levelIntensity(on: Habit.dateKey(for: date))
            return habit.displayColor.opacity(0.4 + intensity * 0.6)
        }
        return habit.displayColor
    }
}
