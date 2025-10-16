//
//  RefreshCoordinator.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/7/25.
//  Coordinates and coalesces notification refresh requests
//

import Foundation

/// Actor that coordinates notification refresh requests to prevent duplicate operations
public actor RefreshCoordinator {
    private var currentRefreshTask: Task<Void, Never>?
    private var isSchedulingInProgress = false
    private let notificationService: AlarmScheduling

    init(notificationService: AlarmScheduling) {
        self.notificationService = notificationService
    }

    /// Request a refresh of all alarms' notifications
    /// If a refresh is already in progress, this will join that operation
    /// rather than starting a duplicate
    public func requestRefresh(alarms: [Alarm]) async {
        // If there's an existing refresh in progress, join it
        if let existingTask = currentRefreshTask,
           !existingTask.isCancelled {
            // Wait for the existing refresh to complete
            await existingTask.value
            return
        }

        // Start a new refresh task using Task.detached to escape view lifecycle
        // This ensures scheduling continues even if the view that triggered it is dismissed
        currentRefreshTask = Task.detached { [weak self] in
            guard let self = self else { return }

            // Mark scheduling as in progress
            await self.setSchedulingInProgress(true)
            defer {
                Task { [weak self] in
                    await self?.setSchedulingInProgress(false)
                }
            }

            // No artificial delay - we coalesce by joining in-flight tasks
            // This will now run independently of any view lifecycle
            await self.notificationService.refreshAll(from: alarms)
        }

        // Wait for completion
        await currentRefreshTask?.value
    }

    /// Check if scheduling is currently in progress
    public func isSchedulingActive() async -> Bool {
        return isSchedulingInProgress
    }

    private func setSchedulingInProgress(_ value: Bool) {
        isSchedulingInProgress = value
    }

    /// Cancel any in-progress refresh operation
    public func cancelCurrentRefresh() {
        currentRefreshTask?.cancel()
        currentRefreshTask = nil
    }
}
