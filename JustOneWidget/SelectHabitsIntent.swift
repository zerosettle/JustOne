//
//  SelectHabitsIntent.swift
//  JustOneWidget
//
//  Configuration intent: lets the user pick which habits to display
//  when editing the widget (long-press → Edit Widget).
//

import AppIntents
import WidgetKit

struct SelectHabitsIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Habits"
    static var description = IntentDescription("Choose which habits to show on your widget.")

    @Parameter(title: "Habits", size: [.systemSmall: 2, .systemMedium: 3])
    var habits: [HabitEntity]?
}
