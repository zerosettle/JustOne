//
//  HabitEntity.swift
//  JustOneWidget
//
//  AppEntity wrapper for Habit, used by the widget configuration picker.
//  Includes the EntityQuery for fetching active habits from SwiftData.
//

import AppIntents
import SwiftData

struct HabitEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Habit")
    static var defaultQuery = HabitEntityQuery()

    var id: UUID
    var name: String
    var icon: String
    var accentColorName: String // raw value of HabitAccentColor
    var customColorHex: String?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", image: .init(systemName: icon))
    }
}

// MARK: - Entity Query

struct HabitEntityQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [HabitEntity] {
        try fetchActiveHabits()
            .filter { identifiers.contains($0.id) }
            .map { $0.toEntity() }
    }

    func suggestedEntities() async throws -> [HabitEntity] {
        try fetchActiveHabits().map { $0.toEntity() }
    }

    func entities(matching string: String) async throws -> [HabitEntity] {
        let lowered = string.lowercased()
        return try fetchActiveHabits()
            .filter { $0.name.lowercased().contains(lowered) }
            .map { $0.toEntity() }
    }

    private func fetchActiveHabits() throws -> [Habit] {
        let container = SharedModelContainer.create()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Habit>()
        return try context.fetch(descriptor).filter { $0.status == .active }
    }
}

// MARK: - Habit → Entity Conversion

extension Habit {
    func toEntity() -> HabitEntity {
        HabitEntity(
            id: id,
            name: name,
            icon: icon,
            accentColorName: accentColor.rawValue,
            customColorHex: customColorHex
        )
    }
}
