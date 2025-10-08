//
//  SoundCatalog.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/24/25.
//

import Foundation

public final class SoundCatalog: SoundCatalogProviding {
    private let sounds: [AlarmSound]
    public let defaultSoundId: String

    public init(bundle: Bundle = .main, validateFiles: Bool = true) {
        // Static catalog - only include actually bundled sounds
        // For now, we only have ringtone1.caf bundled
        self.sounds = [
            AlarmSound(id: "ringtone1", name: "Ringtone", fileName: "ringtone1.caf", durationSec: 27)
        ]

        // Use the actual bundled sound as default
        self.defaultSoundId = "ringtone1"

        if validateFiles {
            validate(bundle: bundle)
        }
    }

    public var all: [AlarmSound] {
        sounds
    }

    public func info(for id: String) -> AlarmSound? {
        sounds.first { $0.id == id }
    }

    private func validate(bundle: Bundle) {
        // Validate unique IDs
        let uniqueIds = Set(sounds.map { $0.id })
        assert(uniqueIds.count == sounds.count, "SoundCatalog: Duplicate sound IDs detected")

        // Validate positive durations
        assert(sounds.allSatisfy { $0.durationSec > 0 }, "SoundCatalog: All durations must be > 0")

        // Validate default ID exists
        assert(info(for: defaultSoundId) != nil, "SoundCatalog: defaultSoundId '\(defaultSoundId)' must exist in catalog")

        // Validate bundle files existence
        for sound in sounds {
            let fileName = sound.fileName
            let nameWithoutExtension = (fileName as NSString).deletingPathExtension
            let fileExtension = (fileName as NSString).pathExtension

            let exists = bundle.url(forResource: nameWithoutExtension, withExtension: fileExtension) != nil

            #if DEBUG
            assert(exists, "SoundCatalog: Missing sound file in bundle: \(fileName)")
            #else
            if !exists {
                print("SoundCatalog WARNING: Missing sound file '\(fileName)'; will use default at schedule time")
            }
            #endif
        }

        print("✅ SoundCatalog: Validation complete - \(sounds.count) sounds, default: '\(defaultSoundId)'")
    }
}

// MARK: - Preview Support

public extension SoundCatalog {
    /// Catalog for SwiftUI previews and tests - bypasses file validation
    static let preview = SoundCatalog(validateFiles: false)
}