//
//  SmallWidgetView.swift
//  JustOneWidget
//
//  Layout for the systemSmall (2×2) widget.
//  Shows "Today" header with completion ratio and 2 habit rows
//  with interactive toggle buttons.
//

import AppIntents
import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let entry: HabitTimelineEntry

    private var completedCount: Int {
        entry.habits.filter(\.isCompletedToday).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("Today")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(completedCount)/\(entry.habits.count)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if entry.habits.isEmpty {
                Spacer()
                Text("Edit widget to pick habits")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                Spacer(minLength: 0)

                // Habit rows (max 2 for small widget)
                ForEach(entry.habits.prefix(2)) { snapshot in
                    habitRow(snapshot)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(4)
    }

    private func habitRow(_ snapshot: HabitTimelineEntry.HabitSnapshot) -> some View {
        let accentColor: Color = {
            if let hex = snapshot.entity.customColorHex { return Color(hex: hex) }
            return HabitAccentColor(rawValue: snapshot.entity.accentColorName)?.color ?? .purple
        }()

        return HStack(spacing: 8) {
            Button(intent: ToggleHabitIntent(habitID: snapshot.id)) {
                Image(systemName: snapshot.isCompletedToday ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(snapshot.isCompletedToday ? accentColor : .secondary.opacity(0.4))
            }
            .buttonStyle(.plain)

            Text(snapshot.entity.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .foregroundStyle(snapshot.isCompletedToday ? .primary : .secondary)
        }
    }
}
