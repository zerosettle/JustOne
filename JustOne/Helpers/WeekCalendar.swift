//
//  WeekCalendar.swift
//  JustOne
//
//  Shared date-math utility for heatmap grids.
//  Produces locale-aware week starts, day labels, and month labels
//  so both the home aggregated heatmap and per-habit contribution
//  graph stay consistent.
//

import Foundation

struct WeekCalendar {
    let weeksToShow: Int
    let referenceDate: Date
    let calendar: Calendar

    init(weeksToShow: Int, referenceDate: Date = Date(), calendar: Calendar = .current) {
        self.weeksToShow = weeksToShow
        self.referenceDate = referenceDate
        self.calendar = calendar
    }

    // MARK: - Week Starts

    /// Start dates for the last `weeksToShow` weeks, ordered oldest → newest.
    var weekStarts: [Date] {
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start else {
            return []
        }
        return (0..<weeksToShow).reversed().compactMap { offset in
            calendar.date(byAdding: .weekOfYear, value: -offset, to: currentWeekStart)
        }
    }

    // MARK: - Day Helpers

    /// Seven consecutive dates starting from `weekStart`.
    func daysInWeek(_ weekStart: Date) -> [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    /// Date for a specific week index (column) and day-of-week index (row).
    func date(week: Int, day: Int) -> Date {
        let starts = weekStarts
        guard week >= 0, week < starts.count else { return referenceDate }
        return calendar.date(byAdding: .day, value: day, to: starts[week])!
    }

    // MARK: - Day Labels

    /// Abbreviated day-of-week labels aligned with row indices (0–6).
    /// Shows a label on even rows (0, 2, 4, 6) and empty string on odd rows.
    var dayLabels: [String] {
        let firstWeekday = calendar.firstWeekday // 1 = Sunday, 2 = Monday, …
        let symbols = calendar.veryShortWeekdaySymbols // ["S", "M", "T", "W", "T", "F", "S"]

        return (0..<7).map { i in
            let weekdayIndex = (firstWeekday - 1 + i) % 7
            return i.isMultiple(of: 2) ? symbols[weekdayIndex] : ""
        }
    }

    // MARK: - Month Labels

    /// Month name labels with their column (week) position index.
    var monthLabels: [(index: Int, name: String)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"

        var labels: [(index: Int, name: String)] = []
        var lastMonth = -1

        for (index, weekStart) in weekStarts.enumerated() {
            let month = calendar.component(.month, from: weekStart)
            if month != lastMonth {
                labels.append((index: index, name: formatter.string(from: weekStart)))
                lastMonth = month
            }
        }
        return labels
    }
}
