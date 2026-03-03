//
//  TimelineProviderTests.swift
//  JustOneTests
//
//  Tests for timeline entry construction logic — verifying that
//  the data feeding into widget views is correct.
//

import Testing
import Foundation
@testable import JustOne

struct TimelineProviderTests {

    // MARK: - Helpers

    private func makeHabit(
        name: String = "Test",
        icon: String = "star.fill",
        accentColor: HabitAccentColor = .purple,
        frequencyPerWeek: Int = 5,
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

    // MARK: - Entry Content

    @Test func entryReflectsCompletionStatus() {
        let today = Date()
        let todayKey = Habit.dateKey(for: today)

        let completed = makeHabit(name: "Done", completedDates: [todayKey])
        let notCompleted = makeHabit(name: "Pending")

        #expect(completed.isCompleted(on: today))
        #expect(!notCompleted.isCompleted(on: today))
    }

    @Test func entryPreservesHabitMetadata() {
        let habit = makeHabit(
            name: "Meditate",
            icon: "brain.head.profile",
            accentColor: .teal,
            frequencyPerWeek: 4
        )

        #expect(habit.name == "Meditate")
        #expect(habit.icon == "brain.head.profile")
        #expect(habit.accentColor == .teal)
        #expect(habit.frequencyPerWeek == 4)
    }

    // MARK: - Refresh Date Logic

    @Test func nextMidnightIsAfterNow() {
        let calendar = Calendar.current
        let now = Date()
        let nextMidnight = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: 1, to: now)!
        )

        #expect(nextMidnight > now)
    }

    @Test func nextMidnightIsStartOfDay() {
        let calendar = Calendar.current
        let now = Date()
        let nextMidnight = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: 1, to: now)!
        )

        let components = calendar.dateComponents([.hour, .minute, .second], from: nextMidnight)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
        #expect(components.second == 0)
    }

    @Test func nextMidnightIsTomorrow() {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let nextMidnight = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: 1, to: now)!
        )

        let dayDiff = calendar.dateComponents([.day], from: today, to: nextMidnight).day
        #expect(dayDiff == 1)
    }

    // MARK: - Multiple Habits Ordering

    @Test func habitsFilteredByConfiguredIDs() {
        let h1 = makeHabit(name: "A")
        let h2 = makeHabit(name: "B")
        let h3 = makeHabit(name: "C")
        let all = [h1, h2, h3]
        let configuredIDs = [h2.id, h3.id]

        let filtered = all.filter { configuredIDs.contains($0.id) }
        #expect(filtered.count == 2)
        #expect(!filtered.contains(where: { $0.id == h1.id }))
    }

    @Test func emptyConfigurationProducesNoHabits() {
        let h1 = makeHabit(name: "A")
        let all = [h1]
        let configuredIDs: [UUID] = []

        let filtered = all.filter { configuredIDs.contains($0.id) }
        #expect(filtered.isEmpty)
    }

    // MARK: - Edge Cases

    @Test func completionOnDayBoundary() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let todayKey = Habit.dateKey(for: today)
        let habit = makeHabit(completedDates: [todayKey])

        #expect(habit.isCompleted(on: today))
        #expect(!habit.isCompleted(on: yesterday))
    }

    @Test func weeklyCompletionsWithNoDates() {
        let habit = makeHabit(completedDates: [])
        #expect(habit.completionsInWeek() == 0)
    }
}
