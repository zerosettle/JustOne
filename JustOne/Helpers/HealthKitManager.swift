//
//  HealthKitManager.swift
//  JustOne
//
//  Reads HealthKit data to auto-complete habits when the user meets
//  their configured thresholds (steps, workouts, sleep, mindful minutes).
//

import HealthKit
import WidgetKit

@MainActor
struct HealthKitManager {
    static let shared = HealthKitManager()

    /// Whether HealthKit is available on this device.
    static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private let store = HKHealthStore()

    // MARK: - Authorization

    /// Requests read-only access for the HealthKit types needed by the given trigger.
    func requestAuthorization(for trigger: HealthKitTrigger) async -> Bool {
        guard Self.isAvailable else { return false }

        let readTypes: Set<HKObjectType> = {
            switch trigger.triggerType {
            case .steps:
                return [HKQuantityType(.stepCount)]
            case .workout:
                return [HKWorkoutType.workoutType()]
            case .sleep:
                return [HKCategoryType(.sleepAnalysis)]
            case .mindfulMinutes:
                return [HKCategoryType(.mindfulSession)]
            }
        }()

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Check All Triggers

    /// Checks all HealthKit-linked habits and auto-completes those that meet their threshold.
    /// Skips habits that were already auto-completed today (respects manual un-completion).
    func checkAllTriggers(for habits: [Habit]) async {
        guard Self.isAvailable else { return }

        let today = Date()
        var didAutoComplete = false

        for habit in habits {
            guard let trigger = habit.healthKitTrigger,
                  habit.status == .active,
                  !habit.isInverse else { continue }

            // Skip if already auto-completed today (user may have unchecked it)
            guard !habit.isAutoCompleted(on: today) else { continue }

            // Skip if already manually completed
            guard !habit.isCompleted(on: today) else { continue }

            let met = await checkTrigger(trigger, on: today)
            if met {
                habit.markAutoCompleted(on: today)
                didAutoComplete = true
            }
        }

        if didAutoComplete {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: - Individual Trigger Checks

    private func checkTrigger(_ trigger: HealthKitTrigger, on date: Date) async -> Bool {
        switch trigger.triggerType {
        case .steps:
            return await checkSteps(threshold: trigger.threshold, on: date)
        case .workout:
            return await checkWorkout(on: date)
        case .sleep:
            return await checkSleep(thresholdHours: trigger.threshold, on: date)
        case .mindfulMinutes:
            return await checkMindful(thresholdMinutes: trigger.threshold, on: date)
        }
    }

    // MARK: - Day Range Helper

    private func dayRange(for date: Date) -> (start: Date, end: Date)? {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        return (start, end)
    }

    // MARK: - Steps

    private func checkSteps(threshold: Double, on date: Date) async -> Bool {
        guard let (start, end) = dayRange(for: date) else { return false }

        let stepType = HKQuantityType(.stepCount)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                let steps = stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: steps >= threshold)
            }
            store.execute(query)
        }
    }

    // MARK: - Workout

    private func checkWorkout(on date: Date) async -> Bool {
        guard let (start, end) = dayRange(for: date) else { return false }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, _ in
                continuation.resume(returning: !(samples?.isEmpty ?? true))
            }
            store.execute(query)
        }
    }

    // MARK: - Sleep

    private func checkSleep(thresholdHours: Double, on date: Date) async -> Bool {
        let calendar = Calendar.current
        // Sleep data for "today" typically spans last night into this morning.
        // Check from 6 PM yesterday to 6 PM today.
        let noon = calendar.startOfDay(for: date)
        guard let start = calendar.date(byAdding: .hour, value: -6, to: noon),
              let end = calendar.date(byAdding: .hour, value: 18, to: noon) else { return false }

        let sleepType = HKCategoryType(.sleepAnalysis)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let asleepCategories: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]

                let totalSeconds = (samples as? [HKCategorySample])?.reduce(0.0) { total, sample in
                    guard asleepCategories.contains(sample.value) else { return total }
                    return total + sample.endDate.timeIntervalSince(sample.startDate)
                } ?? 0

                let totalHours = totalSeconds / 3600
                continuation.resume(returning: totalHours >= thresholdHours)
            }
            store.execute(query)
        }
    }

    // MARK: - Mindful Minutes

    private func checkMindful(thresholdMinutes: Double, on date: Date) async -> Bool {
        guard let (start, end) = dayRange(for: date) else { return false }

        let mindfulType = HKCategoryType(.mindfulSession)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: mindfulType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let totalSeconds = (samples as? [HKCategorySample])?.reduce(0.0) { total, sample in
                    total + sample.endDate.timeIntervalSince(sample.startDate)
                } ?? 0

                let totalMinutes = totalSeconds / 60
                continuation.resume(returning: totalMinutes >= thresholdMinutes)
            }
            store.execute(query)
        }
    }
}
