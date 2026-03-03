//
//  Habit+AppActions.swift
//  JustOne
//
//  App-only extensions on Habit. These methods depend on ZeroSettleKit
//  or WidgetKit and must NOT be added to the widget target.
//

import WidgetKit

extension Habit {

    /// Use a streak saver token to fill in a missed day.
    func fillMissedDay(on date: Date, using manager: ZeroSettleManager) -> Bool {
        guard manager.useStreakSaver() else { return false }
        let key = Self.dateKey(for: date)
        if !completedDates.contains(key) {
            completedDates.append(key)
            invalidateCompletedDatesCache()
        }
        WidgetCenter.shared.reloadAllTimelines()
        return true
    }

    /// Toggle completion and tell WidgetKit to refresh.
    func toggleCompletionAndReloadWidget(on date: Date) {
        toggleCompletion(on: date)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
