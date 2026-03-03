//
//  AppLogger.swift
//  JustOne
//
//  Lightweight namespace for structured os.Logger instances.
//

import OSLog

enum AppLogger {
    static let iap = Logger(subsystem: "io.zerosettle.JustOne", category: "IAP")
}
