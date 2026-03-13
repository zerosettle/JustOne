//
//  HabitInverseTests.swift
//  JustOneTests
//
//  Unit tests for inverse habit behavior: completion inversion,
//  streaks, progress, and slip counting.
//

import Testing
import Foundation
@testable import JustOne

@Suite("Inverse habit completion, streaks, and slip counting")
struct HabitInverseTests {

    // MARK: - Helpers

    private func makeInverseHabit(completedDates: [String] = []) -> Habit {
        Habit(
            name: "No Nail Biting",
            icon: "xmark.circle",
            accentColor: .pink,
            frequencyPerWeek: 7,
            completedDates: completedDates,
            isInverse: true
        )
    }

    private func makeStandardHabit(completedDates: [String] = []) -> Habit {
        Habit(
            name: "Read",
            icon: "book.fill",
            accentColor: .green,
            frequencyPerWeek: 5,
            completedDates: completedDates
        )
    }

    private func dateKey(daysAgo: Int) -> String {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: Date()))!
        return Habit.dateKey(for: date)
    }

    private func date(daysAgo: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: Calendar.current.startOfDay(for: Date()))!
    }

    // MARK: - isInverse Default

    @Test func isInverseDefaultsFalse() {
        let habit = makeStandardHabit()
        #expect(!habit.isInverse)
    }

    @Test func isInverseSetToTrueOnInit() {
        let habit = makeInverseHabit()
        #expect(habit.isInverse)
    }

    // MARK: - Completion Inversion

    @Test func inverseHabitCompletedWhenNotLogged() {
        // No dates logged → inverse habit is "completed" (holding strong)
        let habit = makeInverseHabit()
        #expect(habit.isCompleted(on: Date()))
    }

    @Test func inverseHabitNotCompletedWhenLogged() {
        // Date is logged → inverse habit "slipped" (not completed)
        let todayKey = Habit.dateKey(for: Date())
        let habit = makeInverseHabit(completedDates: [todayKey])
        #expect(!habit.isCompleted(on: Date()))
    }

    @Test func standardHabitUnaffectedByInverseLogic() {
        // Verify existing standard habits work exactly the same
        let habit = makeStandardHabit()
        #expect(!habit.isCompleted(on: Date()))

        habit.toggleCompletion(on: Date())
        #expect(habit.isCompleted(on: Date()))
    }

    @Test func inverseToggleRecordsSlip() {
        let habit = makeInverseHabit()
        // Initially completed (no slips)
        #expect(habit.isCompleted(on: Date()))

        // Toggle = record a slip
        habit.toggleCompletion(on: Date())
        #expect(!habit.isCompleted(on: Date()))

        // Toggle again = undo the slip
        habit.toggleCompletion(on: Date())
        #expect(habit.isCompleted(on: Date()))
    }

    // MARK: - Slip Count

    @Test func slipCountReturnsZeroWhenClean() {
        let habit = makeInverseHabit()
        #expect(habit.slipCount() == 0)
    }

    @Test func slipCountCountsLoggedDatesInWeek() {
        let keys = [dateKey(daysAgo: 0), dateKey(daysAgo: 1), dateKey(daysAgo: 2)]
        let habit = makeInverseHabit(completedDates: keys)
        // The count depends on how many of those 3 days fall in the current week
        let count = habit.slipCount()
        #expect(count >= 1) // At least today is in the current week
        #expect(count <= 3)
    }

    // MARK: - Completions in Week (Inverse)

    @Test func completionsInWeekInvertsForInverse() {
        // Inverse habit with 2 slips this week should have 5+ completions (7 - slips in week)
        let keys = [dateKey(daysAgo: 0), dateKey(daysAgo: 1)]
        let habit = makeInverseHabit(completedDates: keys)
        let completions = habit.completionsInWeek()
        let slips = habit.slipCount()
        // completionsInWeek counts days where isCompleted is true
        // For inverse, that's days WITHOUT a log entry
        #expect(completions + slips == 7) // All 7 days of the week accounted for
    }

    // MARK: - Weekly Progress (Inverse)

    @Test func weeklyProgressFullWhenNoSlips() {
        let habit = makeInverseHabit()
        // 7 completions (all clean) / 7 frequency = 1.0
        #expect(habit.weeklyProgress() == 1.0)
    }

    @Test func weeklyProgressReducedBySlips() {
        let todayKey = Habit.dateKey(for: Date())
        let habit = makeInverseHabit(completedDates: [todayKey])
        // One slip means 6/7 completions
        let progress = habit.weeklyProgress()
        #expect(progress < 1.0)
        #expect(progress > 0.5)
    }

    // MARK: - Streak (Inverse)

    @Test func streakCountsConsecutiveCleanWeeks() {
        // No slips at all → streak should be at least 1 (current week)
        let habit = makeInverseHabit()
        #expect(habit.currentStreak >= 1)
    }

    // MARK: - Regression: Standard Habits Unaffected

    @Test func standardHabitCompletionUnchanged() {
        let todayKey = Habit.dateKey(for: Date())
        let habit = makeStandardHabit(completedDates: [todayKey])
        #expect(habit.isCompleted(on: Date()))
    }

    @Test func standardHabitNotCompletedWhenNoLog() {
        let habit = makeStandardHabit()
        #expect(!habit.isCompleted(on: Date()))
    }
}
