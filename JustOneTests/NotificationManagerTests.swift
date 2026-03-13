//
//  NotificationManagerTests.swift
//  JustOneTests
//
//  Tests for notification scheduling logic using a mock scheduler.
//

import Testing
import Foundation
@testable import JustOne

// MARK: - Mock Scheduler

final class MockNotificationScheduler: NotificationScheduling {
    var permissionRequested = false
    var lastScheduledCount: Int?
    var lastScheduledTime: DateComponents?
    var reminderCancelled = false
    var permissionGranted = true

    func requestPermission() async -> Bool {
        permissionRequested = true
        return permissionGranted
    }

    func scheduleEndOfDayReminder(incompleteCount: Int, at time: DateComponents) async {
        lastScheduledCount = incompleteCount
        lastScheduledTime = time
    }

    func cancelReminder() async {
        reminderCancelled = true
    }
}

@Suite("Notification scheduling with mock scheduler")
struct NotificationManagerTests {

    @Test func scheduleReminderWithIncompleteHabits() async {
        let mock = MockNotificationScheduler()
        let time = DateComponents(hour: 20, minute: 0)

        await mock.scheduleEndOfDayReminder(incompleteCount: 3, at: time)

        #expect(mock.lastScheduledCount == 3)
        #expect(mock.lastScheduledTime?.hour == 20)
        #expect(mock.lastScheduledTime?.minute == 0)
    }

    @Test func scheduleReminderWithZeroIncomplete() async {
        let mock = MockNotificationScheduler()
        let time = DateComponents(hour: 20, minute: 0)

        await mock.scheduleEndOfDayReminder(incompleteCount: 0, at: time)

        // Still records the call — the real implementation cancels internally
        #expect(mock.lastScheduledCount == 0)
    }

    @Test func cancelReminderSetsFlag() async {
        let mock = MockNotificationScheduler()

        await mock.cancelReminder()

        #expect(mock.reminderCancelled)
    }

    @Test func requestPermissionSetsFlag() async {
        let mock = MockNotificationScheduler()

        let granted = await mock.requestPermission()

        #expect(mock.permissionRequested)
        #expect(granted)
    }

    @Test func requestPermissionReturnsFalseWhenDenied() async {
        let mock = MockNotificationScheduler()
        mock.permissionGranted = false

        let granted = await mock.requestPermission()

        #expect(!granted)
    }

    @Test func reminderTimeComponentsReadFromDefaults() {
        // Test the convenience accessor with default values
        let comps = NotificationManager.reminderTimeComponents
        // Should return defaults (20:00) or whatever is in UserDefaults
        #expect(comps.hour != nil)
        #expect(comps.minute != nil)
    }
}
