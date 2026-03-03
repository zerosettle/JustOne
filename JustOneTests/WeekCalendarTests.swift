//
//  WeekCalendarTests.swift
//  JustOneTests
//
//  Unit tests for the WeekCalendar helper.
//  Validates locale-aware week starts, day labels, and month labels.
//

import Testing
import Foundation
@testable import JustOne

struct WeekCalendarTests {

    // MARK: - Helpers

    /// Build a calendar with a specific firstWeekday.
    private func calendar(firstWeekday: Int) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = firstWeekday
        return cal
    }

    /// Fixed reference date: Wednesday, January 15, 2025
    private var referenceDate: Date {
        var comps = DateComponents()
        comps.year = 2025
        comps.month = 1
        comps.day = 15
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    // MARK: - Week Starts

    @Test func weekStartsCount() {
        let wc = WeekCalendar(weeksToShow: 12, referenceDate: referenceDate)
        #expect(wc.weekStarts.count == 12)
    }

    @Test func weekStartsOrderedOldestFirst() {
        let wc = WeekCalendar(weeksToShow: 4, referenceDate: referenceDate)
        let starts = wc.weekStarts
        for i in 1..<starts.count {
            #expect(starts[i] > starts[i - 1])
        }
    }

    @Test func weekStartsSundayLocale() {
        let cal = calendar(firstWeekday: 1) // Sunday
        let wc = WeekCalendar(weeksToShow: 1, referenceDate: referenceDate, calendar: cal)
        let start = wc.weekStarts.first!
        let weekday = cal.component(.weekday, from: start)
        #expect(weekday == 1) // Sunday
    }

    @Test func weekStartsMondayLocale() {
        let cal = calendar(firstWeekday: 2) // Monday
        let wc = WeekCalendar(weeksToShow: 1, referenceDate: referenceDate, calendar: cal)
        let start = wc.weekStarts.first!
        let weekday = cal.component(.weekday, from: start)
        #expect(weekday == 2) // Monday
    }

    // MARK: - Days in Week

    @Test func daysInWeekReturnsSeven() {
        let wc = WeekCalendar(weeksToShow: 1, referenceDate: referenceDate)
        let days = wc.daysInWeek(wc.weekStarts.first!)
        #expect(days.count == 7)
    }

    @Test func daysInWeekAreConsecutive() {
        let cal = Calendar(identifier: .gregorian)
        let wc = WeekCalendar(weeksToShow: 1, referenceDate: referenceDate, calendar: cal)
        let days = wc.daysInWeek(wc.weekStarts.first!)
        for i in 1..<days.count {
            let diff = cal.dateComponents([.day], from: days[i - 1], to: days[i]).day!
            #expect(diff == 1)
        }
    }

    // MARK: - Day Labels

    @Test func dayLabelsCountIsSeven() {
        let wc = WeekCalendar(weeksToShow: 1, referenceDate: referenceDate)
        #expect(wc.dayLabels.count == 7)
    }

    @Test func dayLabelsSundayFirst() {
        let cal = calendar(firstWeekday: 1) // Sunday
        let wc = WeekCalendar(weeksToShow: 1, referenceDate: referenceDate, calendar: cal)
        let labels = wc.dayLabels
        // Even indices get labels, odd indices are empty
        #expect(labels[0] == "S") // Sunday
        #expect(labels[1] == "")
        #expect(labels[2] == "T") // Tuesday
        #expect(labels[4] == "T") // Thursday
        #expect(labels[6] == "S") // Saturday
    }

    @Test func dayLabelsMondayFirst() {
        let cal = calendar(firstWeekday: 2) // Monday
        let wc = WeekCalendar(weeksToShow: 1, referenceDate: referenceDate, calendar: cal)
        let labels = wc.dayLabels
        #expect(labels[0] == "M") // Monday
        #expect(labels[2] == "W") // Wednesday
        #expect(labels[4] == "F") // Friday
        #expect(labels[6] == "S") // Sunday
    }

    @Test func oddDayLabelsAreEmpty() {
        let wc = WeekCalendar(weeksToShow: 1, referenceDate: referenceDate)
        let labels = wc.dayLabels
        #expect(labels[1] == "")
        #expect(labels[3] == "")
        #expect(labels[5] == "")
    }

    // MARK: - Month Labels

    @Test func monthLabelsNotEmpty() {
        let wc = WeekCalendar(weeksToShow: 12, referenceDate: referenceDate)
        #expect(!wc.monthLabels.isEmpty)
    }

    @Test func monthLabelsHaveValidIndices() {
        let wc = WeekCalendar(weeksToShow: 12, referenceDate: referenceDate)
        for label in wc.monthLabels {
            #expect(label.index >= 0)
            #expect(label.index < 12)
        }
    }

    // MARK: - Date Helper

    @Test func dateHelperMatchesDaysInWeek() {
        let wc = WeekCalendar(weeksToShow: 4, referenceDate: referenceDate)
        let weekStart = wc.weekStarts[2]
        let days = wc.daysInWeek(weekStart)
        for day in 0..<7 {
            let fromHelper = wc.date(week: 2, day: day)
            let fromDays = days[day]
            #expect(Calendar.current.isDate(fromHelper, inSameDayAs: fromDays))
        }
    }

    @Test func dateHelperWeekZeroIsOldest() {
        let wc = WeekCalendar(weeksToShow: 4, referenceDate: referenceDate)
        let oldest = wc.date(week: 0, day: 0)
        let newest = wc.date(week: 3, day: 0)
        #expect(oldest < newest)
    }
}
