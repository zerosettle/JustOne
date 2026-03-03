//
//  LockScreenWidgetView.swift
//  JustOneWidget
//
//  Lock screen widget layouts for accessoryRectangular and accessoryCircular.
//  Monochrome, compact views showing today's habit completion at a glance.
//

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Rectangular (3-line lock screen widget)

struct RectangularWidgetView: View {
    let entry: HabitTimelineEntry

    private var completedCount: Int {
        entry.habits.filter(\.isCompletedToday).count
    }

    var body: some View {
        if entry.habits.isEmpty {
            VStack(alignment: .leading) {
                Text("Habits")
                    .font(.headline)
                    .widgetAccentable()
                Text("Edit widget to pick habits")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Today")
                        .font(.caption.weight(.semibold))
                        .widgetAccentable()
                    Spacer()
                    Text("\(completedCount)/\(entry.habits.count)")
                        .font(.caption.weight(.bold).monospacedDigit())
                }

                ForEach(entry.habits.prefix(3)) { snapshot in
                    HStack(spacing: 4) {
                        Image(systemName: snapshot.isCompletedToday ? "checkmark.circle.fill" : "circle")
                            .font(.caption2)
                            .widgetAccentable()

                        Text(snapshot.entity.name)
                            .font(.caption2)
                            .lineLimit(1)

                        Spacer()
                    }
                }
            }
        }
    }
}

// MARK: - Circular (ring showing daily progress)

struct CircularWidgetView: View {
    let entry: HabitTimelineEntry

    private var completedCount: Int {
        entry.habits.filter(\.isCompletedToday).count
    }

    private var totalCount: Int {
        entry.habits.count
    }

    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var body: some View {
        Gauge(value: progress) {
            Text("Habits")
        } currentValueLabel: {
            Text("\(completedCount)/\(totalCount)")
                .font(.system(.body, design: .rounded, weight: .bold))
        }
        .gaugeStyle(.accessoryCircular)
    }
}
