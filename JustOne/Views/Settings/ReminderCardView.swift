//
//  ReminderCardView.swift
//  JustOne
//
//  Toggle and time picker for the daily reminder notification.
//

import SwiftUI

struct ReminderCardView: View {
    @Binding var reminderEnabled: Bool
    @Binding var reminderTime: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundColor(.justPrimary)
                Text("Reminders")
                    .font(.headline)
                Spacer()
            }

            Toggle("Daily reminder", isOn: $reminderEnabled)
                .tint(.justPrimary)
                .onChange(of: reminderEnabled) { _, enabled in
                    UserDefaults.standard.set(enabled, forKey: NotificationKeys.reminderEnabled)
                    if enabled {
                        Task { await NotificationManager.shared.requestPermission() }
                    } else {
                        Task { await NotificationManager.shared.cancelReminder() }
                    }
                }

            if reminderEnabled {
                HStack {
                    Text("Reminder time")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    DatePicker(
                        "",
                        selection: $reminderTime,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .onChange(of: reminderTime) { _, newTime in
                        let comps = Calendar.current.dateComponents([.hour, .minute], from: newTime)
                        UserDefaults.standard.set(comps.hour ?? 20, forKey: NotificationKeys.reminderHour)
                        UserDefaults.standard.set(comps.minute ?? 0, forKey: NotificationKeys.reminderMinute)
                    }
                }
            }
        }
        .padding(20)
        .glassCard()
    }
}
