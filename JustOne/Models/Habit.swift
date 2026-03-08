//
//  Habit.swift
//  JustOne
//
//  SwiftData model for a single habit.
//  Tracks completions as [String] of "yyyy-MM-dd" date keys.
//  Mutation methods live on the model itself.
//  App-only actions (fillMissedDay, widget reload) are in Habit+AppActions.swift.
//

import SwiftUI
import SwiftData

// MARK: - Habit Status

enum HabitStatus: String, Codable, CaseIterable, Identifiable {
    case active, paused, archived

    var id: String { rawValue }
}

// MARK: - Habit Accent Color

enum HabitAccentColor: String, CaseIterable, Identifiable, Codable {
    case purple, blue, teal, pink, orange, green

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .purple: return .habitPurple
        case .blue:   return .habitBlue
        case .teal:   return .habitTeal
        case .pink:   return .habitPink
        case .orange: return .habitOrange
        case .green:  return .habitGreen
        }
    }
}

// MARK: - Habit Model

@Model
class Habit {
    var id: UUID
    var name: String
    var icon: String
    var accentColor: HabitAccentColor
    var frequencyPerWeek: Int
    var completedDates: [String]
    var affirmedDates: [String] = []
    var createdAt: Date
    var journeyConfig: JourneyConfig?        // nil for standard habits
    var pausedJourneyConfig: JourneyConfig?  // stashed config when converting dynamic → standard

    var status: HabitStatus = HabitStatus.active

    /// When true, the habit tracks failures ("slip-ups") instead of completions.
    /// `completedDates` stores dates the user *slipped*, and `isCompleted(on:)` inverts.
    var isInverse: Bool = false

    /// Hex color string for user-picked custom colors. When set, takes priority over `accentColor`.
    var customColorHex: String?

    /// The resolved display color — custom hex if set, otherwise the preset accent color.
    var displayColor: Color {
        if let hex = customColorHex {
            return Color(hex: hex)
        }
        return accentColor.color
    }

    @Transient private var _completedDatesSet: Set<String>?
    @Transient private var _affirmedDatesSet: Set<String>?

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        accentColor: HabitAccentColor,
        frequencyPerWeek: Int,
        completedDates: [String] = [],
        createdAt: Date = Date(),
        journeyConfig: JourneyConfig? = nil,
        status: HabitStatus = .active,
        isInverse: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.accentColor = accentColor
        self.frequencyPerWeek = frequencyPerWeek
        self.completedDates = completedDates
        self.createdAt = createdAt
        self.journeyConfig = journeyConfig
        self.status = status
        self.isInverse = isInverse
    }

    var isJourney: Bool { journeyConfig != nil }

    // MARK: - Date Key Helpers

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dateKey(for date: Date) -> String {
        dayFormatter.string(from: date)
    }

    // MARK: - Completion Queries

    private func completedDatesSet() -> Set<String> {
        if let cached = _completedDatesSet { return cached }
        let set = Set(completedDates)
        _completedDatesSet = set
        return set
    }

    func invalidateCompletedDatesCache() {
        _completedDatesSet = nil
    }

    private func affirmedDatesSet() -> Set<String> {
        if let cached = _affirmedDatesSet { return cached }
        let set = Set(affirmedDates)
        _affirmedDatesSet = set
        return set
    }

    func invalidateAffirmedDatesCache() {
        _affirmedDatesSet = nil
    }

    func isAffirmed(on date: Date) -> Bool {
        affirmedDatesSet().contains(Self.dateKey(for: date))
    }

    func isCompleted(on date: Date) -> Bool {
        let logged = completedDatesSet().contains(Self.dateKey(for: date))
        return isInverse ? !logged : logged
    }

    /// For inverse habits: count of days the user slipped in a given week.
    func slipCount(inWeekOf referenceDate: Date = Date()) -> Int {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else { return 0 }
        var count = 0
        var day = interval.start
        while day < interval.end {
            if completedDatesSet().contains(Self.dateKey(for: day)) { count += 1 }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return count
    }

    func completionsInWeek(of referenceDate: Date = Date()) -> Int {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else { return 0 }
        var count = 0
        var day = interval.start
        while day < interval.end {
            if isCompleted(on: day) { count += 1 }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return count
    }

    func weeklyProgress(referenceDate: Date = Date()) -> Double {
        guard frequencyPerWeek > 0 else { return 0 }
        return min(Double(completionsInWeek(of: referenceDate)) / Double(frequencyPerWeek), 1.0)
    }

    var currentStreak: Int {
        let calendar = Calendar.current
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }

        var streak = 0

        if completionsInWeek(of: currentWeekStart) >= frequencyPerWeek {
            streak += 1
        }

        var cursor = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart)!
        for _ in 0..<52 {
            if completionsInWeek(of: cursor) >= frequencyPerWeek {
                streak += 1
                cursor = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor)!
            } else {
                break
            }
        }
        return streak
    }

    var totalCompletions: Int { completedDates.count }

    // MARK: - Mutations

    func toggleCompletion(on date: Date) {
        let key = Self.dateKey(for: date)
        if let index = completedDates.firstIndex(of: key) {
            completedDates.remove(at: index)
        } else {
            completedDates.append(key)
        }
        invalidateCompletedDatesCache()
    }

    // MARK: - Inverse Habit Actions

    /// Affirm a day (user resisted temptation). Removes slip if present.
    func affirmDay(on date: Date) {
        let key = Self.dateKey(for: date)
        if !affirmedDates.contains(key) {
            affirmedDates.append(key)
        }
        if let index = completedDates.firstIndex(of: key) {
            completedDates.remove(at: index)
        }
        invalidateCompletedDatesCache()
        invalidateAffirmedDatesCache()
    }

    /// Log a slip (user gave in). Removes affirm if present.
    func logSlip(on date: Date) {
        let key = Self.dateKey(for: date)
        if !completedDates.contains(key) {
            completedDates.append(key)
        }
        if let index = affirmedDates.firstIndex(of: key) {
            affirmedDates.remove(at: index)
        }
        invalidateCompletedDatesCache()
        invalidateAffirmedDatesCache()
    }

    /// Undo an affirm.
    func undoAffirm(on date: Date) {
        let key = Self.dateKey(for: date)
        if let index = affirmedDates.firstIndex(of: key) {
            affirmedDates.remove(at: index)
        }
        invalidateAffirmedDatesCache()
    }

    /// Undo a slip (remove from completedDates).
    func undoSlip(on date: Date) {
        let key = Self.dateKey(for: date)
        if let index = completedDates.firstIndex(of: key) {
            completedDates.remove(at: index)
        }
        invalidateCompletedDatesCache()
    }

    // MARK: - Journey Methods

    /// Check if the user qualifies for a level-up on a journey habit.
    /// Returns true if they've completed the habit for `pacingDays` consecutive days
    /// at the current level and aren't already at the final level.
    func qualifiesForLevelUp() -> Bool {
        guard let config = journeyConfig, !config.isAtFinalLevel else { return false }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for dayOffset in 0..<config.pacingDays {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                return false
            }
            if !isCompleted(on: date) { return false }
        }
        return true
    }

    /// Advance to the next level. Records today's date in levelUpDates.
    func levelUp() {
        guard var config = journeyConfig, !config.isAtFinalLevel else { return }
        config.currentLevel += 1
        let todayKey = Self.dateKey(for: Date())
        config.levelUpDates.append(todayKey)
        journeyConfig = config
    }

    /// Step back to the previous level.
    func levelDown() {
        guard var config = journeyConfig, config.currentLevel > 0 else { return }
        config.currentLevel -= 1
        // Remove the most recent level-up date entry
        if !config.levelUpDates.isEmpty {
            config.levelUpDates.removeLast()
        }
        journeyConfig = config
    }

    /// Smart recalculation after editing journey config.
    func updateJourneyConfig(_ newConfig: JourneyConfig) {
        let oldTarget = journeyConfig?.currentTarget ?? newConfig.startValue
        var updated = newConfig
        updated.recalculate(oldCurrentTarget: oldTarget)
        journeyConfig = updated
    }

    // MARK: - Habit Type Conversion

    /// Convert from progressive journey → standard. Stashes the config so it can be restored.
    func convertToStandard() {
        guard let config = journeyConfig else { return }
        pausedJourneyConfig = config
        journeyConfig = nil
    }

    /// Convert from standard → progressive journey. Restores stashed config if available.
    func convertToJourney(with config: JourneyConfig? = nil) {
        if let config = config {
            journeyConfig = config
        } else if let stashed = pausedJourneyConfig {
            journeyConfig = stashed
        }
        pausedJourneyConfig = nil
    }
}
