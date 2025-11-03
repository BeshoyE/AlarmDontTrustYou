//
//  ShareProvider.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/15/25.
//  Infrastructure layer - UIKit isolation for sharing content
//

import UIKit

// MARK: - Protocol

/// Protocol for sharing content via UIActivityViewController
/// @MainActor ensures all UIKit presentation occurs on main thread
@MainActor
protocol ShareProviding {
    /// Presents a share sheet with the given items
    /// - Parameter items: Array of items to share (strings, URLs, etc.)
    func share(items: [Any])
}

// MARK: - Implementation

/// System implementation of ShareProviding using UIActivityViewController
/// @MainActor ensures all UIKit access is main-thread safe
@MainActor
final class SystemShareProvider: ShareProviding {

    func share(items: [Any]) {
        // Find the root view controller from the active window scene
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            print("ShareProvider: No root view controller available")
            return
        }

        // Create activity view controller
        let activityVC = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )

        // iPad support: configure popover to prevent crash
        // On iPad, UIActivityViewController must be presented in a popover
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = rootVC.view
            popover.sourceRect = CGRect(
                x: rootVC.view.bounds.midX,
                y: rootVC.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }

        // Present on main thread (already guaranteed by @MainActor)
        rootVC.present(activityVC, animated: true)
    }
}
