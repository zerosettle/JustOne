//
//  JourneyConfig.swift
//  JustOne
//
//  Data model for Progressive Journey habits — progressive overload tracking.
//  Stores value type, direction, milestones, and level-up history.
//

import Foundation

// MARK: - Journey Value Type

enum JourneyValueType: String, Codable, CaseIterable, Identifiable {
    case time, weight, duration, count, custom, frequency

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .time:     return "Time"
        case .weight:   return "Weight"
        case .duration: return "Duration"
        case .count:    return "Count"
        case .custom:    return "Custom"
        case .frequency: return "Frequency"
        }
    }

    var defaultUnit: String {
        switch self {
        case .time:     return "AM/PM"
        case .weight:   return "lbs"
        case .duration: return "min"
        case .count:    return ""
        case .custom:    return ""
        case .frequency: return "×/week"
        }
    }

    var defaultDirection: JourneyDirection {
        switch self {
        case .time:     return .decreasing  // Earlier wake = progress
        case .weight:   return .increasing
        case .duration: return .increasing
        case .count:    return .increasing
        case .custom:    return .increasing
        case .frequency: return .increasing
        }
    }

    var iconName: String {
        switch self {
        case .time:     return "clock.fill"
        case .weight:   return "dumbbell.fill"
        case .duration: return "timer"
        case .count:    return "number"
        case .custom:    return "slider.horizontal.3"
        case .frequency: return "calendar.badge.plus"
        }
    }

    func format(_ value: Double, customUnit: String = "") -> String {
        switch self {
        case .time:
            let totalMinutes = Int(value)
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            let hour12 = hours % 12 == 0 ? 12 : hours % 12
            let period = hours < 12 ? "AM" : "PM"
            return String(format: "%d:%02d %@", hour12, minutes, period)
        case .weight:
            if value == value.rounded() {
                return "\(Int(value)) lbs"
            }
            return String(format: "%.1f lbs", value)
        case .duration:
            let totalMinutes = Int(value)
            if totalMinutes >= 60 {
                let hours = totalMinutes / 60
                let mins = totalMinutes % 60
                return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
            }
            return "\(totalMinutes) min"
        case .count:
            if value == value.rounded() {
                return "\(Int(value))"
            }
            return String(format: "%.1f", value)
        case .custom:
            if value == value.rounded() {
                return "\(Int(value)) \(customUnit)"
            }
            return String(format: "%.1f %@", value, customUnit)
        case .frequency:
            return "\(Int(value))×/week"
        }
    }
}

// MARK: - Journey Direction

enum JourneyDirection: String, Codable, CaseIterable, Identifiable {
    case increasing  // Higher = progress (weight, reps, duration)
    case decreasing  // Lower = progress (earlier wake time)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .increasing: return "Increasing"
        case .decreasing: return "Decreasing"
        }
    }
}

// MARK: - Journey Config

struct JourneyConfig: Codable {
    var valueType: JourneyValueType
    var direction: JourneyDirection
    var customUnit: String
    var startValue: Double
    var goalValue: Double
    var increment: Double             // Always stored as positive
    var pacingDays: Int
    var currentLevel: Int             // 0-based index into milestones
    var levelUpDates: [String]        // Date keys ("yyyy-MM-dd") when user leveled up

    init(
        valueType: JourneyValueType,
        direction: JourneyDirection? = nil,
        customUnit: String = "",
        startValue: Double,
        goalValue: Double,
        increment: Double,
        pacingDays: Int = 14,
        currentLevel: Int = 0,
        levelUpDates: [String] = []
    ) {
        self.valueType = valueType
        self.direction = direction ?? valueType.defaultDirection
        self.customUnit = customUnit
        self.startValue = startValue
        self.goalValue = goalValue
        self.increment = abs(increment)
        self.pacingDays = pacingDays
        self.currentLevel = currentLevel
        self.levelUpDates = levelUpDates
    }

    // MARK: - Computed Properties

    /// All milestone values from start to goal, always including goal as the final entry.
    var milestones: [Double] {
        var result: [Double] = []
        var current = startValue

        switch direction {
        case .increasing:
            while current < goalValue - increment * 0.01 {
                result.append(current)
                current += increment
            }
        case .decreasing:
            while current > goalValue + increment * 0.01 {
                result.append(current)
                current -= increment
            }
        }

        // Always include goalValue as the final milestone
        if result.isEmpty || result.last != goalValue {
            result.append(goalValue)
        }

        return result
    }

    var totalLevels: Int {
        milestones.count
    }

    var currentTarget: Double {
        let ms = milestones
        guard currentLevel >= 0, currentLevel < ms.count else {
            return ms.last ?? startValue
        }
        return ms[currentLevel]
    }

    var isAtFinalLevel: Bool {
        currentLevel >= totalLevels - 1
    }

    var nextTarget: Double? {
        let ms = milestones
        let nextIndex = currentLevel + 1
        guard nextIndex < ms.count else { return nil }
        return ms[nextIndex]
    }

    // MARK: - Formatting

    func formattedValue(_ value: Double) -> String {
        valueType.format(value, customUnit: customUnit)
    }

    // MARK: - Date-Based Level Lookup

    /// Derive the active level for a given date key ("yyyy-MM-dd").
    /// Iterates levelUpDates to find the last level-up on or before the query date.
    func levelOnDate(_ dateKey: String) -> Int {
        var level = 0
        for (index, upDate) in levelUpDates.enumerated() {
            if upDate <= dateKey {
                level = index + 1  // Each level-up moves to the next level
            } else {
                break
            }
        }
        return min(level, totalLevels - 1)
    }

    /// Returns 0.0–1.0 intensity for heatmap coloring based on the level at a given date.
    func levelIntensity(on dateKey: String) -> Double {
        guard totalLevels > 1 else { return 1.0 }
        let level = levelOnDate(dateKey)
        return Double(level) / Double(totalLevels - 1)
    }

    // MARK: - Smart Recalculation

    /// Finds the closest milestone in the new config to the old current target.
    /// On ties, favors the lower level (conservative). Trims levelUpDates to match.
    mutating func recalculate(oldCurrentTarget: Double) {
        let ms = milestones
        guard !ms.isEmpty else {
            currentLevel = 0
            levelUpDates = []
            return
        }

        var closestIndex = 0
        var closestDistance = abs(ms[0] - oldCurrentTarget)

        for (index, milestone) in ms.enumerated() {
            let distance = abs(milestone - oldCurrentTarget)
            if distance < closestDistance {
                closestDistance = distance
                closestIndex = index
            }
            // On ties, the earlier index wins (conservative) since we use strict <
        }

        currentLevel = closestIndex

        // Trim levelUpDates: keep only entries up to the new level count
        if levelUpDates.count > currentLevel {
            levelUpDates = Array(levelUpDates.prefix(currentLevel))
        }
    }
}
