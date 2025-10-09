//
//  DependencyContainerKey.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/8/25.
//  Environment key for dependency injection (eliminates singleton pattern)
//

import SwiftUI

private struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue: DependencyContainer? = nil
}

extension EnvironmentValues {
    var container: DependencyContainer? {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}
