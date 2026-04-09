//
//  SharedModelContainer.swift
//  JustOne
//
//  Creates a SwiftData ModelContainer backed by the App Group container,
//  so both the main app and the widget extension share the same store.
//  Handles one-time migration from the default store location.
//

import SwiftData
import Foundation

enum SharedModelContainer {
    static let appGroupID = "group.io.zerosettle.JustOne"

    private static let migrationKey = "SharedModelContainer.migrationCompleted"

    /// Cached container — created once and reused on every access.
    /// Returning a new instance on each call caused `.modelContainer()`
    /// to tear down the window content (new reference ≠ old reference),
    /// cancelling all in-flight `.task` modifiers including bootstrap.
    private static let cached: ModelContainer = {
        let schema = Schema([Habit.self])

        if let groupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("JustOne.store") {
            migrateIfNeeded(to: groupURL)
            let config = ModelConfiguration(url: groupURL)
            if let container = try? ModelContainer(for: schema, configurations: [config]) {
                return container
            }
        }

        let fallbackConfig = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [fallbackConfig])
    }()

    static func create() -> ModelContainer {
        cached
    }

    /// One-time migration: copy old default store to App Group location.
    /// Uses a UserDefaults flag so we only attempt once, and runs BEFORE
    /// ModelContainer is created (which would create an empty DB).
    private static func migrateIfNeeded(to groupURL: URL) {
        let defaults = UserDefaults(suiteName: appGroupID)
        guard defaults?.bool(forKey: migrationKey) != true else { return }
        defer { defaults?.set(true, forKey: migrationKey) }

        let fm = FileManager.default

        // Default SwiftData store location
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let oldURL = appSupport.appendingPathComponent("default.store")
        guard fm.fileExists(atPath: oldURL.path) else { return }

        // Remove any empty DB that a previous launch may have created
        for suffix in ["", "-wal", "-shm"] {
            let dst = URL(fileURLWithPath: groupURL.path + suffix)
            try? fm.removeItem(at: dst)
        }

        // Copy main store + WAL + SHM
        try? fm.copyItem(at: oldURL, to: groupURL)
        for suffix in ["-wal", "-shm"] {
            let src = URL(fileURLWithPath: oldURL.path + suffix)
            let dst = URL(fileURLWithPath: groupURL.path + suffix)
            if fm.fileExists(atPath: src.path) {
                try? fm.copyItem(at: src, to: dst)
            }
        }
    }
}
