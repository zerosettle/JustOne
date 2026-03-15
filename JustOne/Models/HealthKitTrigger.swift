//
//  HealthKitTrigger.swift
//  JustOne
//
//  Codable trigger that links a habit to a HealthKit data type.
//  When the user's health data meets the threshold, the habit
//  is automatically marked complete.
//

import Foundation

enum HealthKitTriggerType: String, Codable, CaseIterable, Identifiable {
    case steps          // Daily step count >= threshold
    case workout        // Any workout completed today
    case sleep          // Sleep >= threshold hours
    case mindfulMinutes // Mindful session >= threshold minutes

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .steps:          return "Steps"
        case .workout:        return "Workout"
        case .sleep:          return "Sleep"
        case .mindfulMinutes: return "Mindful"
        }
    }

    var icon: String {
        switch self {
        case .steps:          return "figure.walk"
        case .workout:        return "dumbbell.fill"
        case .sleep:          return "moon.zzz.fill"
        case .mindfulMinutes: return "brain.head.profile.fill"
        }
    }

    var unit: String {
        switch self {
        case .steps:          return "steps"
        case .workout:        return ""
        case .sleep:          return "hours"
        case .mindfulMinutes: return "min"
        }
    }

    var defaultThreshold: Double {
        switch self {
        case .steps:          return 10_000
        case .workout:        return 1
        case .sleep:          return 7
        case .mindfulMinutes: return 10
        }
    }

    /// Whether this trigger type uses a threshold the user can configure.
    var hasConfigurableThreshold: Bool {
        self != .workout
    }
}

struct HealthKitTrigger: Codable, Equatable {
    var triggerType: HealthKitTriggerType
    var threshold: Double  // steps count, sleep hours, mindful minutes (workout ignores this)
}
