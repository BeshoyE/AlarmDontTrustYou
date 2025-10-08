//
//  SoundCatalogProviding.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/24/25.
//

import Foundation

public protocol SoundCatalogProviding {
    var all: [AlarmSound] { get }
    var defaultSoundId: String { get }
    func info(for id: String) -> AlarmSound?
}

// MARK: - Safe Helper Extension

public extension SoundCatalogProviding {
    /// Safe sound lookup that falls back to default if ID is missing or invalid
    /// Prevents UI crashes when dealing with unknown sound IDs
    func safeInfo(for id: String?) -> AlarmSound? {
        if let id = id, let sound = info(for: id) {
            return sound
        }
        return info(for: defaultSoundId)
    }
}