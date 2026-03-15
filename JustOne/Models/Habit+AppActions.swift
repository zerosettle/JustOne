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
    @MainActor func fillMissedDay(on date: Date, using manager: PurchaseManager) -> Bool {
        guard manager.useStreakSaver() else { return false }
        let key = Self.dateKey(for: date)
        if !completedDates.contains(key) {
            completedDates.append(key)
            invalidateCompletedDatesCache()
        }
        WidgetCenter.shared.reloadAllTimelines()
        return true
    }

    /// Auto-complete via HealthKit and tell WidgetKit to refresh.
    func markAutoCompletedAndReloadWidget(on date: Date) {
        markAutoCompleted(on: date)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Toggle completion and tell WidgetKit to refresh.
    func toggleCompletionAndReloadWidget(on date: Date) {
        toggleCompletion(on: date)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Affirm day (inverse habit) and tell WidgetKit to refresh.
    func affirmDayAndReloadWidget(on date: Date) {
        affirmDay(on: date)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Log slip (inverse habit) and tell WidgetKit to refresh.
    func logSlipAndReloadWidget(on date: Date) {
        logSlip(on: date)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Undo affirm (inverse habit) and tell WidgetKit to refresh.
    func undoAffirmAndReloadWidget(on date: Date) {
        undoAffirm(on: date)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Undo slip (inverse habit) and tell WidgetKit to refresh.
    func undoSlipAndReloadWidget(on date: Date) {
        undoSlip(on: date)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
