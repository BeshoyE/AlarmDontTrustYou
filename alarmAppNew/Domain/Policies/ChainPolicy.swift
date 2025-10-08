//
//  ChainPolicy.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/1/25.
//

import Foundation
import os.log

public struct ChainConfiguration {
    public let spacingSeconds: Int
    public let chainCount: Int
    public let totalDurationSeconds: Int

    public init(spacingSeconds: Int, chainCount: Int) {
        self.spacingSeconds = spacingSeconds
        self.chainCount = chainCount
        self.totalDurationSeconds = spacingSeconds * max(1, chainCount)
    }

    public func trimmed(to maxCount: Int) -> ChainConfiguration {
        let actualCount = max(1, min(chainCount, maxCount))
        return ChainConfiguration(spacingSeconds: spacingSeconds, chainCount: actualCount)
    }
}

public struct ChainSettings {
    public let maxChainCount: Int
    public let ringWindowSec: Int
    public let fallbackSpacingSec: Int
    public let minLeadTimeSec: Int
    public let cleanupGraceSec: Int

    public init(maxChainCount: Int = 12, ringWindowSec: Int = 180, fallbackSpacingSec: Int = 30, minLeadTimeSec: Int = 10, cleanupGraceSec: Int = 60) {
        // Validate and clamp to safe ranges
        let clampedMax = max(1, min(50, maxChainCount))
        let clampedWindow = max(30, min(600, ringWindowSec))
        let clampedSpacing = max(1, min(30, fallbackSpacingSec))
        let clampedLeadTime = max(5, min(30, minLeadTimeSec))
        let clampedGrace = max(30, min(300, cleanupGraceSec))

        self.maxChainCount = clampedMax
        self.ringWindowSec = clampedWindow
        self.fallbackSpacingSec = clampedSpacing
        self.minLeadTimeSec = clampedLeadTime
        self.cleanupGraceSec = clampedGrace

        // Log any coercions for observability
        if maxChainCount != clampedMax {
            os_log("ChainSettings: clamped maxChainCount %d -> %d",
                   log: .default, type: .info, maxChainCount, clampedMax)
        }
        if ringWindowSec != clampedWindow {
            os_log("ChainSettings: clamped ringWindowSec %d -> %d",
                   log: .default, type: .info, ringWindowSec, clampedWindow)
        }
        if fallbackSpacingSec != clampedSpacing {
            os_log("ChainSettings: clamped fallbackSpacingSec %d -> %d",
                   log: .default, type: .info, fallbackSpacingSec, clampedSpacing)
        }
        if minLeadTimeSec != clampedLeadTime {
            os_log("ChainSettings: clamped minLeadTimeSec %d -> %d",
                   log: .default, type: .info, minLeadTimeSec, clampedLeadTime)
        }
        if cleanupGraceSec != clampedGrace {
            os_log("ChainSettings: clamped cleanupGraceSec %d -> %d",
                   log: .default, type: .info, cleanupGraceSec, clampedGrace)
        }
    }
}

public struct ChainPolicy {
    public let settings: ChainSettings

    public init(settings: ChainSettings = ChainSettings()) {
        self.settings = settings
    }

    public func normalizedSpacing(_ rawSeconds: Int) -> Int {
        return max(1, min(30, rawSeconds))
    }

    public func computeChain(spacingSeconds: Int) -> ChainConfiguration {
        let normalizedSpacing = normalizedSpacing(spacingSeconds)

        // Calculate how many notifications fit in the ring window
        let theoreticalCount = settings.ringWindowSec / normalizedSpacing

        // Cap at configured maximum and ensure at least 1
        let actualCount = max(1, min(settings.maxChainCount, theoreticalCount))

        return ChainConfiguration(spacingSeconds: normalizedSpacing, chainCount: actualCount)
    }

    public func computeFireDates(baseFireDate: Date, configuration: ChainConfiguration) -> [Date] {
        var dates: [Date] = []

        for occurrence in 0..<configuration.chainCount {
            let offsetSeconds = TimeInterval(occurrence * configuration.spacingSeconds)
            let fireDate = baseFireDate.addingTimeInterval(offsetSeconds)
            dates.append(fireDate)
        }

        return dates
    }
}

// MARK: - Extensions for convenience

extension ChainSettings: Codable, Equatable {
    public static let defaultSettings = ChainSettings()
}

extension ChainConfiguration: Equatable {
    public static func == (lhs: ChainConfiguration, rhs: ChainConfiguration) -> Bool {
        return lhs.spacingSeconds == rhs.spacingSeconds &&
               lhs.chainCount == rhs.chainCount
    }
}