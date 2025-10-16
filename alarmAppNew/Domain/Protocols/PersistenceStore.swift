//
//  PersistenceStore.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/17/25.
//  Protocol for persistent alarm storage with mandatory Actor conformance per CLAUDE.md §5
//

import Foundation

/// Protocol for persistent alarm storage with actor-based concurrency safety.
/// All implementations MUST be actors to prevent data races.
public protocol PersistenceStore: Actor {
  func loadAlarms() throws -> [Alarm]
  func saveAlarms(_ alarm:[Alarm]) throws
}
