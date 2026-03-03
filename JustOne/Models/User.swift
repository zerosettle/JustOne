//
//  User.swift
//  JustOne
//
//  Lightweight user session model. Codable for UserDefaults persistence.
//

import Foundation

struct User: Identifiable, Codable {
    let id: UUID
    var displayName: String
    var email: String?
    var avatarSystemName: String
    var joinedAt: Date
}
