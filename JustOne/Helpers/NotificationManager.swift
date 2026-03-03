//
//  NotificationManager.swift
//  JustOne
//
//  Manages local notification scheduling for end-of-day habit reminders.
//  Uses a protocol for testability.
//

import UserNotifications

// MARK: - Protocol

protocol NotificationScheduling {
    func requestPermission() async -> Bool
    func scheduleEndOfDayReminder(incompleteCount: Int, at time: DateComponents) async
    func cancelReminder() async
}

// MARK: - Keys

enum NotificationKeys {
    static let reminderEnabled = "reminderEnabled"
    static let reminderHour = "reminderHour"
    static let reminderMinute = "reminderMinute"
    static let hasRequestedPermission = "hasRequestedNotificationPermission"

    static var defaultHour: Int { 20 }    // 8 PM
    static var defaultMinute: Int { 0 }
}

// MARK: - NotificationManager

struct NotificationManager: NotificationScheduling {
    static let shared = NotificationManager()

    private static let reminderIdentifier = "io.zerosettle.JustOne.dailyReminder"

    // MARK: - Permission

    @discardableResult
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            UserDefaults.standard.set(true, forKey: NotificationKeys.hasRequestedPermission)
            return granted
        } catch {
            return false
        }
    }

    // MARK: - Schedule

    func scheduleEndOfDayReminder(incompleteCount: Int, at time: DateComponents) async {
        let center = UNUserNotificationCenter.current()

        // Remove any existing reminder first
        center.removePendingNotificationRequests(withIdentifiers: [Self.reminderIdentifier])

        guard incompleteCount > 0 else { return }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Don't break your streak"
        content.body = incompleteCount == 1
            ? "You have 1 habit left to complete today."
            : "You have \(incompleteCount) habits left to complete today."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = time.hour
        dateComponents.minute = time.minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.reminderIdentifier,
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    // MARK: - Cancel

    func cancelReminder() async {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.reminderIdentifier])
    }

    // MARK: - Convenience

    /// Reads the user's preferred reminder time from UserDefaults.
    static var reminderTimeComponents: DateComponents {
        let hour = UserDefaults.standard.object(forKey: NotificationKeys.reminderHour) as? Int
            ?? NotificationKeys.defaultHour
        let minute = UserDefaults.standard.object(forKey: NotificationKeys.reminderMinute) as? Int
            ?? NotificationKeys.defaultMinute
        return DateComponents(hour: hour, minute: minute)
    }

    static var isReminderEnabled: Bool {
        // Default to true if never explicitly set
        if UserDefaults.standard.object(forKey: NotificationKeys.reminderEnabled) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: NotificationKeys.reminderEnabled)
    }
}
