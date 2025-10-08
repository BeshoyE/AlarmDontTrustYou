//
//  DefaultAlarmFactory.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/24/25.
//

import Foundation

public final class DefaultAlarmFactory: AlarmFactory {
    private let catalog: SoundCatalogProviding

    public init(catalog: SoundCatalogProviding) {
        self.catalog = catalog
    }

    public func makeNewAlarm() -> Alarm {
        Alarm(
            id: UUID(),
            time: Date().addingTimeInterval(3600), // Default to 1 hour from now
            label: "New Alarm",
            repeatDays: [],
            challengeKind: [],
            expectedQR: nil,
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: true,
            soundId: catalog.defaultSoundId,  // Use catalog's default sound
            soundName: nil,                   // Legacy field - will be phased out
            volume: 0.8
        )
    }
}