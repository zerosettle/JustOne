//
//  SeedData.swift
//  JustOne
//
//  Temporary seed data for App Store screenshots.
//  DELETE THIS FILE after capturing screenshots.
//

import SwiftData
import Foundation

enum SeedData {

    /// Seed the model context with demo habits for screenshots.
    /// Clears existing data and inserts fresh demo habits.
    static func seedIfNeeded(context: ModelContext) {
        let seededKey = "screenshotDataSeeded"
        guard !UserDefaults.standard.bool(forKey: seededKey) else { return }

        // Clear existing habits
        if let existing = try? context.fetch(FetchDescriptor<Habit>()) {
            for habit in existing { context.delete(habit) }
        }
        UserDefaults.standard.set(true, forKey: seededKey)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // MARK: - Helper: generate date keys

        func dateKey(_ date: Date) -> String {
            Habit.dateKey(for: date)
        }

        func daysAgo(_ n: Int) -> Date {
            calendar.date(byAdding: .day, value: -n, to: today)!
        }

        /// Generate completed date keys with a given consistency (0.0–1.0).
        /// `skipToday` leaves today unmarked so the user can tap it in the screenshot.
        func generateCompletions(
            daysBack: Int,
            consistency: Double,
            frequencyPerWeek: Int = 7,
            skipToday: Bool = false,
            weekendBias: Bool = false
        ) -> [String] {
            var dates: [String] = []
            for i in (skipToday ? 1 : 0)..<daysBack {
                let date = daysAgo(i)
                let weekday = calendar.component(.weekday, from: date)
                let isWeekend = weekday == 1 || weekday == 7

                // For frequency < 7, skip some days naturally
                if frequencyPerWeek < 7 {
                    let dayOfWeek = calendar.component(.weekday, from: date)
                    // Spread completions across the week
                    let targetDays: Set<Int>
                    switch frequencyPerWeek {
                    case 1: targetDays = [2] // Monday
                    case 2: targetDays = [2, 5]
                    case 3: targetDays = [2, 4, 6]
                    case 4: targetDays = [2, 3, 5, 6]
                    case 5: targetDays = [2, 3, 4, 5, 6]
                    case 6: targetDays = [2, 3, 4, 5, 6, 7]
                    default: targetDays = Set(1...7)
                    }
                    guard targetDays.contains(dayOfWeek) else { continue }
                }

                var chance = consistency
                if weekendBias && isWeekend { chance *= 0.6 }
                // Slightly higher consistency in recent weeks (momentum effect)
                if i < 14 { chance = min(chance + 0.1, 1.0) }

                if Double.random(in: 0...1) < chance {
                    dates.append(dateKey(date))
                }
            }
            return dates
        }

        // MARK: - 1. Morning Meditation (daily, 12 weeks, high consistency)

        let meditation = Habit(
            name: "Morning Meditation",
            icon: "brain.head.profile",
            accentColor: .purple,
            frequencyPerWeek: 7,
            completedDates: generateCompletions(daysBack: 84, consistency: 0.88, skipToday: true),
            createdAt: daysAgo(84)
        )

        // MARK: - 2. Read 30 Minutes (daily, 10 weeks, good consistency)

        let reading = Habit(
            name: "Read 30 Minutes",
            icon: "book.fill",
            accentColor: .blue,
            frequencyPerWeek: 7,
            completedDates: generateCompletions(daysBack: 70, consistency: 0.82, skipToday: true, weekendBias: true),
            createdAt: daysAgo(70)
        )

        // MARK: - 3. Exercise (5x/week, journey habit — progressive)

        let exerciseLevelUpDates = [
            dateKey(daysAgo(56)),  // Level 1 → 2
            dateKey(daysAgo(42)),  // Level 2 → 3
            dateKey(daysAgo(28)),  // Level 3 → 4
            dateKey(daysAgo(14)),  // Level 4 → 5
        ]

        let exercise = Habit(
            name: "Exercise",
            icon: "figure.run",
            accentColor: .green,
            frequencyPerWeek: 5,
            completedDates: generateCompletions(daysBack: 70, consistency: 0.85, frequencyPerWeek: 5, skipToday: true),
            createdAt: daysAgo(70),
            journeyConfig: JourneyConfig(
                valueType: .duration,
                startValue: 15,
                goalValue: 45,
                increment: 5,
                pacingDays: 14,
                currentLevel: 4,
                levelUpDates: exerciseLevelUpDates
            )
        )

        // MARK: - 4. Drink Water (daily, high consistency — simple)

        let water = Habit(
            name: "Drink 8 Glasses",
            icon: "drop.fill",
            accentColor: .teal,
            frequencyPerWeek: 7,
            completedDates: generateCompletions(daysBack: 56, consistency: 0.92, skipToday: true),
            createdAt: daysAgo(56)
        )

        // MARK: - 5. No Social Media (inverse habit — breaking)

        // For inverse habits, completedDates = slip-up days (days the user gave in).
        // A few scattered slips over 6 weeks — mostly clean.
        var socialMediaSlips: [String] = []
        let slipDays = [4, 11, 18, 29, 43] // specific days ago they slipped
        for d in slipDays {
            socialMediaSlips.append(dateKey(daysAgo(d)))
        }

        let noSocialMedia = Habit(
            name: "No Doomscrolling",
            icon: "iphone.slash",
            accentColor: .pink,
            frequencyPerWeek: 7,
            completedDates: socialMediaSlips,
            createdAt: daysAgo(49),
            isInverse: true
        )

        // MARK: - 6. Journal (3x/week, solid consistency)

        let journal = Habit(
            name: "Journal",
            icon: "pencil.and.scribble",
            accentColor: .orange,
            frequencyPerWeek: 3,
            completedDates: generateCompletions(daysBack: 63, consistency: 0.9, frequencyPerWeek: 3, skipToday: true),
            createdAt: daysAgo(63)
        )

        // MARK: - Insert all

        let habits = [meditation, reading, exercise, water, noSocialMedia, journal]
        for habit in habits {
            context.insert(habit)
        }

        // MARK: - Set streak saver tokens (looks pro)

        UserDefaults.standard.set(7, forKey: "streakSaverTokens")
    }
}
