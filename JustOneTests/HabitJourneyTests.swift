//
//  HabitJourneyTests.swift
//  JustOneTests
//
//  Unit tests for journey habits: level transitions, qualification,
//  conversion between journey and standard modes.
//

import Testing
import Foundation
@testable import JustOne

@Suite("Journey habit level transitions, milestones, and conversion")
struct HabitJourneyTests {

    // MARK: - Helpers

    private func makeJourneyHabit(
        completedDates: [String] = [],
        config: JourneyConfig = JourneyConfig(
            valueType: .weight,
            startValue: 100,
            goalValue: 150,
            increment: 10,
            pacingDays: 3
        )
    ) -> Habit {
        Habit(
            name: "Bench Press",
            icon: "dumbbell.fill",
            accentColor: .blue,
            frequencyPerWeek: 3,
            completedDates: completedDates,
            journeyConfig: config
        )
    }

    private func makeStandardHabit() -> Habit {
        Habit(
            name: "Read",
            icon: "book.fill",
            accentColor: .green,
            frequencyPerWeek: 5
        )
    }

    private func dateKey(daysAgo: Int) -> String {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: Date()))!
        return Habit.dateKey(for: date)
    }

    // MARK: - isJourney

    @Test func isJourneyTrueWhenConfigPresent() {
        let habit = makeJourneyHabit()
        #expect(habit.isJourney)
    }

    @Test func isJourneyFalseForStandardHabit() {
        let habit = makeStandardHabit()
        #expect(!habit.isJourney)
    }

    // MARK: - Journey Config Milestones

    @Test func milestonesIncreasingDirection() {
        let config = JourneyConfig(
            valueType: .weight,
            direction: .increasing,
            startValue: 100,
            goalValue: 130,
            increment: 10
        )
        // 100, 110, 120, 130
        #expect(config.milestones == [100, 110, 120, 130])
        #expect(config.totalLevels == 4)
    }

    @Test func milestonesDecreasingDirection() {
        let config = JourneyConfig(
            valueType: .time,
            direction: .decreasing,
            startValue: 480, // 8:00 AM
            goalValue: 420,  // 7:00 AM
            increment: 15
        )
        // 480, 465, 450, 435, 420
        #expect(config.milestones == [480, 465, 450, 435, 420])
        #expect(config.totalLevels == 5)
    }

    @Test func milestonesAlwaysIncludeGoal() {
        // increment doesn't divide evenly into the range
        let config = JourneyConfig(
            valueType: .count,
            direction: .increasing,
            startValue: 0,
            goalValue: 25,
            increment: 10
        )
        // 0, 10, 20, 25
        #expect(config.milestones.last == 25)
        #expect(config.milestones.contains(25))
    }

    @Test func currentTargetAtLevel0() {
        let config = JourneyConfig(
            valueType: .weight,
            startValue: 100,
            goalValue: 150,
            increment: 10
        )
        #expect(config.currentTarget == 100)
    }

    @Test func nextTargetAtLevel0() {
        let config = JourneyConfig(
            valueType: .weight,
            startValue: 100,
            goalValue: 150,
            increment: 10
        )
        #expect(config.nextTarget == 110)
    }

    @Test func isAtFinalLevelFalseAtStart() {
        let config = JourneyConfig(
            valueType: .weight,
            startValue: 100,
            goalValue: 150,
            increment: 10
        )
        #expect(!config.isAtFinalLevel)
    }

    @Test func isAtFinalLevelTrueAtGoal() {
        var config = JourneyConfig(
            valueType: .weight,
            startValue: 100,
            goalValue: 120,
            increment: 10
        )
        // milestones: [100, 110, 120] — 3 levels, indices 0..2
        config.currentLevel = 2
        #expect(config.isAtFinalLevel)
        #expect(config.nextTarget == nil)
    }

    // MARK: - qualifiesForLevelUp

    @Test func qualifiesForLevelUpWhenConsecutiveDaysCompleted() {
        // pacingDays = 3, need today + yesterday + 2 days ago
        let dates = [dateKey(daysAgo: 0), dateKey(daysAgo: 1), dateKey(daysAgo: 2)]
        let habit = makeJourneyHabit(completedDates: dates)
        #expect(habit.qualifiesForLevelUp())
    }

    @Test func doesNotQualifyWithGapInDays() {
        // pacingDays = 3, missing yesterday
        let dates = [dateKey(daysAgo: 0), dateKey(daysAgo: 2)]
        let habit = makeJourneyHabit(completedDates: dates)
        #expect(!habit.qualifiesForLevelUp())
    }

    @Test func doesNotQualifyWhenAtFinalLevel() {
        let dates = [dateKey(daysAgo: 0), dateKey(daysAgo: 1), dateKey(daysAgo: 2)]
        var config = JourneyConfig(
            valueType: .weight,
            startValue: 100,
            goalValue: 120,
            increment: 10,
            pacingDays: 3
        )
        // At final level (index 2 of [100, 110, 120])
        config.currentLevel = 2
        let habit = makeJourneyHabit(completedDates: dates, config: config)
        #expect(!habit.qualifiesForLevelUp())
    }

    @Test func doesNotQualifyForStandardHabit() {
        let habit = makeStandardHabit()
        #expect(!habit.qualifiesForLevelUp())
    }

    // MARK: - levelUp

    @Test func levelUpIncrementsLevel() {
        let habit = makeJourneyHabit()
        #expect(habit.journeyConfig?.currentLevel == 0)
        habit.levelUp()
        #expect(habit.journeyConfig?.currentLevel == 1)
    }

    @Test func levelUpRecordsDateInLevelUpDates() {
        let habit = makeJourneyHabit()
        habit.levelUp()
        let todayKey = Habit.dateKey(for: Date())
        #expect(habit.journeyConfig?.levelUpDates.contains(todayKey) == true)
    }

    @Test func levelUpDoesNothingAtFinalLevel() {
        var config = JourneyConfig(
            valueType: .weight,
            startValue: 100,
            goalValue: 120,
            increment: 10,
            pacingDays: 3
        )
        config.currentLevel = 2 // final level of [100, 110, 120]
        let habit = makeJourneyHabit(config: config)
        habit.levelUp()
        #expect(habit.journeyConfig?.currentLevel == 2)
    }

    @Test func multipleLevelUps() {
        let habit = makeJourneyHabit()
        habit.levelUp()
        habit.levelUp()
        #expect(habit.journeyConfig?.currentLevel == 2)
        #expect(habit.journeyConfig?.levelUpDates.count == 2)
    }

    // MARK: - levelDown

    @Test func levelDownDecrementsLevel() {
        let habit = makeJourneyHabit()
        habit.levelUp()
        #expect(habit.journeyConfig?.currentLevel == 1)
        habit.levelDown()
        #expect(habit.journeyConfig?.currentLevel == 0)
    }

    @Test func levelDownRemovesLastLevelUpDate() {
        let habit = makeJourneyHabit()
        habit.levelUp()
        habit.levelUp()
        #expect(habit.journeyConfig?.levelUpDates.count == 2)
        habit.levelDown()
        #expect(habit.journeyConfig?.levelUpDates.count == 1)
    }

    @Test func levelDownDoesNothingAtLevel0() {
        let habit = makeJourneyHabit()
        #expect(habit.journeyConfig?.currentLevel == 0)
        habit.levelDown()
        #expect(habit.journeyConfig?.currentLevel == 0)
    }

    // MARK: - convertToStandard / convertToJourney

    @Test func convertToStandardRemovesJourneyConfig() {
        let habit = makeJourneyHabit()
        #expect(habit.isJourney)
        habit.convertToStandard()
        #expect(!habit.isJourney)
        #expect(habit.journeyConfig == nil)
    }

    @Test func convertToStandardStashesConfig() {
        let habit = makeJourneyHabit()
        habit.convertToStandard()
        #expect(habit.pausedJourneyConfig != nil)
    }

    @Test func convertToJourneyRestoresStashedConfig() {
        let habit = makeJourneyHabit()
        let originalStart = habit.journeyConfig?.startValue
        habit.convertToStandard()
        habit.convertToJourney()
        #expect(habit.isJourney)
        #expect(habit.journeyConfig?.startValue == originalStart)
        #expect(habit.pausedJourneyConfig == nil)
    }

    @Test func convertToJourneyWithNewConfig() {
        let habit = makeStandardHabit()
        let newConfig = JourneyConfig(
            valueType: .duration,
            startValue: 10,
            goalValue: 60,
            increment: 5
        )
        habit.convertToJourney(with: newConfig)
        #expect(habit.isJourney)
        #expect(habit.journeyConfig?.valueType == .duration)
        #expect(habit.journeyConfig?.startValue == 10)
    }

    @Test func convertToJourneyWithoutConfigOrStash() {
        let habit = makeStandardHabit()
        habit.convertToJourney()
        // No stash and no new config — should remain standard
        #expect(!habit.isJourney)
    }

    // MARK: - updateJourneyConfig / recalculate

    @Test func updateJourneyConfigSnapsToClosestMilestone() {
        let habit = makeJourneyHabit()
        habit.levelUp() // now at level 1, target = 110

        // Change increment from 10 to 15: milestones become [100, 115, 130, 145, 150]
        let newConfig = JourneyConfig(
            valueType: .weight,
            startValue: 100,
            goalValue: 150,
            increment: 15,
            pacingDays: 3
        )
        habit.updateJourneyConfig(newConfig)

        // Old target was 110, closest milestone is 115 (index 1)
        #expect(habit.journeyConfig?.currentLevel == 1)
        #expect(habit.journeyConfig?.currentTarget == 115)
    }

    @Test func recalculateTrimsLevelUpDates() {
        let habit = makeJourneyHabit()
        habit.levelUp()
        habit.levelUp()
        habit.levelUp()
        #expect(habit.journeyConfig?.levelUpDates.count == 3)

        // Recalculate to a config where the closest level is 1
        var newConfig = JourneyConfig(
            valueType: .weight,
            startValue: 100,
            goalValue: 150,
            increment: 10,
            pacingDays: 3,
            levelUpDates: habit.journeyConfig?.levelUpDates ?? []
        )
        // Simulate: old target was level 3 = 130, new increment 25 → milestones [100, 125, 150]
        // Closest to 130 is 125 (index 1)
        newConfig = JourneyConfig(
            valueType: .weight,
            startValue: 100,
            goalValue: 150,
            increment: 25,
            pacingDays: 3,
            levelUpDates: habit.journeyConfig?.levelUpDates ?? []
        )
        habit.updateJourneyConfig(newConfig)
        #expect(habit.journeyConfig?.currentLevel == 1)
        #expect(habit.journeyConfig?.levelUpDates.count == 1)
    }

    // MARK: - levelOnDate / levelIntensity

    @Test func levelOnDateReturnsCorrectLevel() {
        var config = JourneyConfig(
            valueType: .weight,
            startValue: 100,
            goalValue: 150,
            increment: 10,
            pacingDays: 3,
            currentLevel: 2,
            levelUpDates: ["2026-01-10", "2026-02-01"]
        )
        // Before any level-up
        #expect(config.levelOnDate("2026-01-05") == 0)
        // After first level-up
        #expect(config.levelOnDate("2026-01-15") == 1)
        // After second level-up
        #expect(config.levelOnDate("2026-02-15") == 2)
        // On the exact date of first level-up
        #expect(config.levelOnDate("2026-01-10") == 1)
    }

    @Test func levelIntensityScalesCorrectly() {
        let config = JourneyConfig(
            valueType: .weight,
            startValue: 100,
            goalValue: 150,
            increment: 10,
            pacingDays: 3,
            currentLevel: 0,
            levelUpDates: ["2026-01-10", "2026-02-01"]
        )
        // totalLevels = 6 (100, 110, 120, 130, 140, 150)
        // Before any level-up: level 0, intensity = 0/5 = 0.0
        #expect(config.levelIntensity(on: "2026-01-05") == 0.0)
        // After first level-up: level 1, intensity = 1/5 = 0.2
        #expect(config.levelIntensity(on: "2026-01-15") == 0.2)
    }

    @Test func levelIntensityReturns1ForSingleLevel() {
        let config = JourneyConfig(
            valueType: .count,
            startValue: 10,
            goalValue: 10,
            increment: 5,
            pacingDays: 3
        )
        // Only 1 milestone — intensity should always be 1.0
        #expect(config.levelIntensity(on: "2026-01-01") == 1.0)
    }
}
