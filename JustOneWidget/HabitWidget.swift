//
//  HabitWidget.swift
//  JustOneWidget
//
//  Widget definition and timeline provider.
//  Fetches configured habits from the shared SwiftData store
//  and refreshes at midnight or on-demand after a toggle.
//

import SwiftUI
import SwiftData
import WidgetKit

// MARK: - Timeline Entry

struct HabitTimelineEntry: TimelineEntry {
    let date: Date
    let habits: [HabitSnapshot]

    struct HabitSnapshot: Identifiable {
        let id: UUID
        let entity: HabitEntity
        let isCompletedToday: Bool
        let weeklyCompleted: Int
        let weeklyTotal: Int
    }
}

// MARK: - Timeline Provider

struct HabitTimelineProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> HabitTimelineEntry {
        HabitTimelineEntry(date: Date(), habits: [
            .init(id: UUID(), entity: HabitEntity(id: UUID(), name: "Meditate", icon: "brain.head.profile", accentColorName: "purple"), isCompletedToday: true, weeklyCompleted: 3, weeklyTotal: 5),
            .init(id: UUID(), entity: HabitEntity(id: UUID(), name: "Exercise", icon: "figure.run", accentColorName: "blue"), isCompletedToday: false, weeklyCompleted: 1, weeklyTotal: 4),
            .init(id: UUID(), entity: HabitEntity(id: UUID(), name: "Read", icon: "book.fill", accentColorName: "green"), isCompletedToday: true, weeklyCompleted: 5, weeklyTotal: 7),
        ])
    }

    func snapshot(for configuration: SelectHabitsIntent, in context: Context) async -> HabitTimelineEntry {
        fetchEntry(for: configuration)
    }

    func timeline(for configuration: SelectHabitsIntent, in context: Context) async -> Timeline<HabitTimelineEntry> {
        let entry = fetchEntry(for: configuration)
        // Refresh at next midnight
        let nextMidnight = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        )
        return Timeline(entries: [entry], policy: .after(nextMidnight))
    }

    private func fetchEntry(for configuration: SelectHabitsIntent) -> HabitTimelineEntry {
        let container = SharedModelContainer.create()
        let context = ModelContext(container)
        let habitIDs = (configuration.habits ?? []).map(\.id)

        // Fetch all habits and filter to configured IDs
        let descriptor = FetchDescriptor<Habit>()
        let allHabits = (try? context.fetch(descriptor)) ?? []
        let habits = allHabits.filter { habitIDs.contains($0.id) }

        let snapshots = habits.map { habit in
            HabitTimelineEntry.HabitSnapshot(
                id: habit.id,
                entity: habit.toEntity(),
                isCompletedToday: habit.isCompleted(on: Date()),
                weeklyCompleted: habit.completionsInWeek(),
                weeklyTotal: habit.frequencyPerWeek
            )
        }
        return HabitTimelineEntry(date: Date(), habits: snapshots)
    }
}

// MARK: - Widget Definition

struct HabitWidget: Widget {
    let kind = "HabitWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectHabitsIntent.self,
            provider: HabitTimelineProvider()
        ) { entry in
            HabitWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Habits")
        .description("Track your daily habits.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

// MARK: - Entry View Router

private struct HabitWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: HabitTimelineEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .accessoryRectangular:
            RectangularWidgetView(entry: entry)
        case .accessoryCircular:
            CircularWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}
