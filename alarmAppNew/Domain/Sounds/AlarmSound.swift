//
//  AlarmSound.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/24/25.
//

import Foundation

public struct AlarmSound: Identifiable, Codable, Equatable {
    public let id: String         // stable key, e.g. "chimes01"
    public let name: String       // display label
    public let fileName: String   // includes extension, e.g. "chimes01.caf"
    public let durationSec: Int   // >0; descriptive only

    public init(id: String, name: String, fileName: String, durationSec: Int) {
        self.id = id
        self.name = name
        self.fileName = fileName
        self.durationSec = durationSec
    }
}