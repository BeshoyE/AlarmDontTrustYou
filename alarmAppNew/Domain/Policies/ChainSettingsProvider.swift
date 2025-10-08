//
//  ChainSettingsProvider.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/1/25.
//

import Foundation

public protocol ChainSettingsProviding {
    func chainSettings() -> ChainSettings
    func validateSettings(_ settings: ChainSettings) -> ChainSettingsValidationResult
}

public enum ChainSettingsValidationResult {
    case valid
    case invalid(reasons: [String])

    public var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    public var errorReasons: [String] {
        if case .invalid(let reasons) = self { return reasons }
        return []
    }
}

public final class DefaultChainSettingsProvider: ChainSettingsProviding {

    public init() {}

    public func chainSettings() -> ChainSettings {
        // Production defaults optimized for "continuous ring" feel
        // - maxChainCount: 12 (up from 5) for better coverage over 5-minute window
        // - fallbackSpacingSec: 10 (down from 30) for faster repetition when sound duration unknown
        // - minLeadTimeSec: 10 to ensure iOS fires notifications reliably
        // - Spacing auto-adjusts to sound duration when available (e.g., 27s for chimes01)
        return ChainSettings(
            maxChainCount: 12,
            ringWindowSec: 300,
            fallbackSpacingSec: 10,
            minLeadTimeSec: 10
        )
    }

    public func validateSettings(_ settings: ChainSettings) -> ChainSettingsValidationResult {
        var errors: [String] = []

        // Validate chain count
        if settings.maxChainCount < 1 {
            errors.append("maxChainCount must be at least 1")
        }
        if settings.maxChainCount > 15 {
            errors.append("maxChainCount should not exceed 15 (iOS notification limit considerations)")
        }

        // Validate ring window
        if settings.ringWindowSec < 30 {
            errors.append("ringWindowSec must be at least 30 seconds")
        }
        if settings.ringWindowSec > 600 {
            errors.append("ringWindowSec should not exceed 600 seconds (10 minutes)")
        }

        // Validate fallback spacing
        if settings.fallbackSpacingSec < 5 {
            errors.append("fallbackSpacingSec must be at least 5 seconds")
        }
        if settings.fallbackSpacingSec > 60 {
            errors.append("fallbackSpacingSec should not exceed 60 seconds")
        }

        // Validate minimum lead time
        if settings.minLeadTimeSec < 5 {
            errors.append("minLeadTimeSec must be at least 5 seconds")
        }
        if settings.minLeadTimeSec > 30 {
            errors.append("minLeadTimeSec should not exceed 30 seconds")
        }

        // Cross-validation: ensure ring window can accommodate at least one chain
        let minPossibleDuration = settings.fallbackSpacingSec * settings.maxChainCount
        if settings.ringWindowSec < minPossibleDuration {
            errors.append("ringWindowSec too small for maxChainCount at fallbackSpacingSec")
        }

        return errors.isEmpty ? .valid : .invalid(reasons: errors)
    }
}