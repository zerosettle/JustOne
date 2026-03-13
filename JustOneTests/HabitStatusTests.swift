//
//  HabitStatusTests.swift
//  JustOneTests
//
//  Unit tests for HabitStatus lifecycle, filtering, and streak-freeze behavior.
//

import Testing
import Foundation
@testable import JustOne

@Suite("Habit status lifecycle, filtering, and streak-freeze behavior")
struct HabitStatusTests {

    // MARK: - Helpers

    private func makeHabit(
        status: HabitStatus = .active,
        frequencyPerWeek: Int = 3,
        completedDates: [String] = []
    ) -> Habit {
        Habit(
            name: "Test",
            icon: "star.fill",
            accentColor: .purple,
            frequencyPerWeek: frequencyPerWeek,
            completedDates: completedDates,
            status: status
        )
    }

    // MARK: - Default Status

    @Test func defaultStatusIsActive() {
        let habit = Habit(
            name: "Test",
            icon: "star.fill",
            accentColor: .purple,
            frequencyPerWeek: 3
        )
        #expect(habit.status == .active)
    }

    // MARK: - Status Transitions

    @Test func activeTosPaused() {
        let habit = makeHabit(status: .active)
        habit.status = .paused
        #expect(habit.status == .paused)
    }

    @Test func pausedToActive() {
        let habit = makeHabit(status: .paused)
        habit.status = .active
        #expect(habit.status == .active)
    }

    @Test func activeToArchived() {
        let habit = makeHabit(status: .active)
        habit.status = .archived
        #expect(habit.status == .archived)
    }

    @Test func archivedToActive() {
        let habit = makeHabit(status: .archived)
        habit.status = .active
        #expect(habit.status == .active)
    }

    // MARK: - Filtering

    @Test func filterActiveOnly() {
        let habits = [
            makeHabit(status: .active),
            makeHabit(status: .paused),
            makeHabit(status: .archived),
            makeHabit(status: .active)
        ]
        let active = habits.filter { $0.status == .active }
        #expect(active.count == 2)
    }

    @Test func filterVisibleExcludesArchived() {
        let habits = [
            makeHabit(status: .active),
            makeHabit(status: .paused),
            makeHabit(status: .archived)
        ]
        let visible = habits.filter { $0.status != .archived }
        #expect(visible.count == 2)
    }

    @Test func filterActiveExcludesPaused() {
        let habits = [
            makeHabit(status: .active),
            makeHabit(status: .paused)
        ]
        let active = habits.filter { $0.status == .active }
        #expect(active.count == 1)
        #expect(active.first?.status == .active)
    }

    // MARK: - Completion Queries Still Work Across Status

    @Test func completionQueriesWorkOnPausedHabit() {
        let today = Habit.dateKey(for: Date())
        let habit = makeHabit(status: .paused, completedDates: [today])
        #expect(habit.isCompleted(on: Date()))
    }

    @Test func completionQueriesWorkOnArchivedHabit() {
        let today = Habit.dateKey(for: Date())
        let habit = makeHabit(status: .archived, completedDates: [today])
        #expect(habit.isCompleted(on: Date()))
    }

    // MARK: - Set Cache

    @Test func setCacheReturnsCorrectResults() {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let habit = makeHabit(completedDates: [Habit.dateKey(for: today)])

        #expect(habit.isCompleted(on: today))
        #expect(!habit.isCompleted(on: yesterday))
    }

    @Test func setCacheInvalidatesOnToggle() {
        let today = Date()
        let habit = makeHabit()

        #expect(!habit.isCompleted(on: today))
        habit.toggleCompletion(on: today)
        #expect(habit.isCompleted(on: today))
        habit.toggleCompletion(on: today)
        #expect(!habit.isCompleted(on: today))
    }
}
