//
//  SettingsViewModel.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/15/25.
//  Presentation layer for Settings screen
//

import Foundation
import Combine

/// ViewModel for SettingsView
/// Handles export logs logic without direct UIKit dependencies
@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - Dependencies

    private let reliabilityLogger: ReliabilityLogging
    private let shareProvider: ShareProviding

    // MARK: - Init

    init(
        reliabilityLogger: ReliabilityLogging,
        shareProvider: ShareProviding
    ) {
        self.reliabilityLogger = reliabilityLogger
        self.shareProvider = shareProvider
    }

    // MARK: - Public Methods

    /// Exports reliability logs and presents share sheet
    /// - Note: Runs log export on background queue (reliabilityLogger handles thread safety)
    ///         Then presents share sheet on main thread via shareProvider
    func exportLogs() {
        // Export logs on background queue to avoid blocking UI
        Task.detached(priority: .userInitiated) {
            // Call reliabilityLogger.exportLogs() which uses its own dispatch queue
            let logs = self.reliabilityLogger.exportLogs()

            // Present share sheet on main thread (shareProvider is @MainActor)
            await MainActor.run {
                self.shareProvider.share(items: [logs])
            }
        }
    }
}
