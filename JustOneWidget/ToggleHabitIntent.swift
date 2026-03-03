//
//  ToggleHabitIntent.swift
//  JustOneWidget
//
//  Interactive AppIntent: tapping the checkmark on the widget
//  toggles the habit's completion for today and reloads timelines.
//

import AppIntents
import SwiftData
import WidgetKit

struct ToggleHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Habit"

    @Parameter(title: "Habit ID")
    var habitID: String

    init() {}

    init(habitID: UUID) {
        self.habitID = habitID.uuidString
    }

    func perform() async throws -> some IntentResult {
        let container = SharedModelContainer.create()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Habit>()
        let habits = try context.fetch(descriptor)
        guard let targetID = UUID(uuidString: habitID),
              let habit = habits.first(where: { $0.id == targetID }) else {
            return .result()
        }
        habit.toggleCompletion(on: Date())
        try context.save()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
