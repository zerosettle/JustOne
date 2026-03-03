//
//  MediumWidgetView.swift
//  JustOneWidget
//
//  Layout for the systemMedium (2×4) widget.
//  Shows "Today" header with completion ratio and up to 3 habit rows,
//  each with an interactive toggle, icon badge, name, and weekly progress.
//

import AppIntents
import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let entry: HabitTimelineEntry

    private var completedCount: Int {
        entry.habits.filter(\.isCompletedToday).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                Text("Today")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(completedCount)/\(entry.habits.count)")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if entry.habits.isEmpty {
                Spacer()
                Text("Edit widget to pick habits")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                Spacer(minLength: 0)

                // Habit rows (max 3 for medium widget)
                ForEach(entry.habits.prefix(3)) { snapshot in
                    habitRow(snapshot)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(4)
    }

    private func habitRow(_ snapshot: HabitTimelineEntry.HabitSnapshot) -> some View {
        let accentColor = HabitAccentColor(rawValue: snapshot.entity.accentColorName)?.color ?? .purple

        return HStack(spacing: 10) {
            // Interactive toggle
            Button(intent: ToggleHabitIntent(habitID: snapshot.id)) {
                Image(systemName: snapshot.isCompletedToday ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(snapshot.isCompletedToday ? accentColor : .secondary.opacity(0.4))
            }
            .buttonStyle(.plain)

            // Icon badge
            Image(systemName: snapshot.entity.icon)
                .font(.caption)
                .foregroundStyle(accentColor)
                .frame(width: 24, height: 24)
                .background(accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))

            // Habit name
            Text(snapshot.entity.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .foregroundStyle(snapshot.isCompletedToday ? .primary : .secondary)

            Spacer()

            // Weekly progress
            Text("\(snapshot.weeklyCompleted)/\(snapshot.weeklyTotal) this wk")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
    }
}
