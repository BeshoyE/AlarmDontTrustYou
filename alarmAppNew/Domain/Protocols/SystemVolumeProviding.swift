//
//  SystemVolumeProviding.swift
//  alarmAppNew
//
//  Domain protocol for system volume operations.
//  Pure protocol definition with no platform dependencies.
//

import Foundation

/// Protocol for accessing system volume information
public protocol SystemVolumeProviding {
    /// Returns the current media volume (0.0–1.0)
    /// Note: This reads media volume only. Ringer volume is not accessible via public APIs.
    func currentMediaVolume() -> Float
}