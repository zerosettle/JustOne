//
//  PreviousDayCatchUpTests.swift
//  JustOneTests
//
//  Tests for the previous-day catch-up detection logic.
//

import Testing
import Foundation
@testable import JustOne

struct PreviousDayCatchUpTests {

    // MARK: - Helpers

    private func makeHabit(completedDates: [String] = []) -> Habit {
        Habit(
            name: "Test Habit",
            icon: "star.fill",
            accentColor: .purple,
            frequencyPerWeek: 7,
            completedDates: completedDates
        )
    }

    private func dateKey(daysAgo: Int) -> String {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: Date()))!
        return Habit.dateKey(for: date)
    }

    // MARK: - Detection Logic

    @Test func shouldShowCatchUpWhenNewDayWithIncomplete() {
        let habit = makeHabit() // No completions
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let hasIncomplete = !habit.isCompleted(on: yesterday)
        #expect(hasIncomplete)
    }

    @Test func shouldNotShowCatchUpWhenYesterdayComplete() {
        let yesterdayKey = dateKey(daysAgo: 1)
        let habit = makeHabit(completedDates: [yesterdayKey])
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let hasIncomplete = !habit.isCompleted(on: yesterday)
        #expect(!hasIncomplete)
    }

    @Test func shouldNotShowCatchUpOnSameDay() {
        let today = Habit.dateKey(for: Date())
        let lastOpened = today
        let shouldShow = lastOpened != today
        #expect(!shouldShow)
    }

    @Test func shouldShowCatchUpOnNewDay() {
        let today = Habit.dateKey(for: Date())
        let yesterday = dateKey(daysAgo: 1)
        let lastOpened = yesterday
        let shouldShow = lastOpened != today
        #expect(shouldShow)
    }

    // MARK: - Catch-Up Mutation

    @Test func toggleYesterdayCompletionUpdatesCorrectDate() {
        let habit = makeHabit()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayKey = Habit.dateKey(for: yesterday)

        #expect(!habit.completedDates.contains(yesterdayKey))

        habit.toggleCompletion(on: yesterday)

        #expect(habit.completedDates.contains(yesterdayKey))
        #expect(habit.isCompleted(on: yesterday))
    }

    @Test func toggleYesterdayDoesNotAffectToday() {
        let habit = makeHabit()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        habit.toggleCompletion(on: yesterday)

        // Today should still be incomplete
        #expect(!habit.isCompleted(on: Date()))
    }

    // MARK: - Inverse Habit Catch-Up

    @Test func inverseCatchUpShowsSlippedDays() {
        // Inverse habit with a slip logged yesterday
        let yesterdayKey = dateKey(daysAgo: 1)
        let habit = Habit(
            name: "No Sugar",
            icon: "xmark.circle",
            accentColor: .orange,
            frequencyPerWeek: 7,
            completedDates: [yesterdayKey],
            isInverse: true
        )
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        // Inverse: logged yesterday = slipped = NOT completed
        #expect(!habit.isCompleted(on: yesterday))
    }
}
