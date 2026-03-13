//
//  WidgetIntentTests.swift
//  JustOneTests
//
//  Tests for Habit → HabitEntity conversion and toggle intent behavior.
//  These test the model-level logic that feeds into the widget intents.
//

import Testing
import Foundation
@testable import JustOne

@Suite("Habit entity conversion and toggle intent behavior")
struct WidgetIntentTests {

    // MARK: - Helpers

    private func makeHabit(
        name: String = "Test",
        icon: String = "star.fill",
        accentColor: HabitAccentColor = .purple,
        frequencyPerWeek: Int = 3,
        completedDates: [String] = [],
        status: HabitStatus = .active
    ) -> Habit {
        Habit(
            name: name,
            icon: icon,
            accentColor: accentColor,
            frequencyPerWeek: frequencyPerWeek,
            completedDates: completedDates,
            status: status
        )
    }

    // MARK: - Toggle Completion (core logic used by widget intent)

    @Test func toggleCompletionAddsDateKey() {
        let habit = makeHabit()
        let today = Date()
        #expect(!habit.isCompleted(on: today))

        habit.toggleCompletion(on: today)
        #expect(habit.isCompleted(on: today))
    }

    @Test func toggleCompletionRemovesDateKey() {
        let today = Date()
        let todayKey = Habit.dateKey(for: today)
        let habit = makeHabit(completedDates: [todayKey])
        #expect(habit.isCompleted(on: today))

        habit.toggleCompletion(on: today)
        #expect(!habit.isCompleted(on: today))
    }

    @Test func toggleCompletionIsIdempotentRoundTrip() {
        let habit = makeHabit()
        let today = Date()

        habit.toggleCompletion(on: today)
        habit.toggleCompletion(on: today)
        #expect(!habit.isCompleted(on: today))

        habit.toggleCompletion(on: today)
        #expect(habit.isCompleted(on: today))
    }

    // MARK: - Filtering Active Habits (used by entity query)

    @Test func onlyActiveHabitsAreQueried() {
        let habits = [
            makeHabit(name: "Active1", status: .active),
            makeHabit(name: "Paused", status: .paused),
            makeHabit(name: "Archived", status: .archived),
            makeHabit(name: "Active2", status: .active)
        ]
        let active = habits.filter { $0.status == .active }
        #expect(active.count == 2)
        #expect(active.map(\.name) == ["Active1", "Active2"])
    }

    @Test func filterByIDSubset() {
        let h1 = makeHabit(name: "H1")
        let h2 = makeHabit(name: "H2")
        let h3 = makeHabit(name: "H3")
        let all = [h1, h2, h3]
        let targetIDs = [h1.id, h3.id]

        let filtered = all.filter { targetIDs.contains($0.id) }
        #expect(filtered.count == 2)
        #expect(filtered.map(\.name) == ["H1", "H3"])
    }

    // MARK: - Weekly Progress (used by medium widget)

    @Test func weeklyCompletionsCountCorrectly() {
        let calendar = Calendar.current
        let today = Date()

        // Build date keys for this week
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else {
            Issue.record("Could not determine week interval")
            return
        }

        var keys: [String] = []
        var day = weekInterval.start
        for _ in 0..<3 {
            keys.append(Habit.dateKey(for: day))
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }

        let habit = makeHabit(frequencyPerWeek: 5, completedDates: keys)
        #expect(habit.completionsInWeek() == 3)
        #expect(habit.frequencyPerWeek == 5)
    }

    @Test func weeklyProgressCapsAtOne() {
        let calendar = Calendar.current
        let today = Date()
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else {
            Issue.record("Could not determine week interval")
            return
        }

        // Complete every day this week
        var keys: [String] = []
        var day = weekInterval.start
        for _ in 0..<7 {
            keys.append(Habit.dateKey(for: day))
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }

        let habit = makeHabit(frequencyPerWeek: 3, completedDates: keys)
        #expect(habit.weeklyProgress() == 1.0)
    }
}
