//
//  debug.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 9/4/25.
//

import UserNotifications
import SwiftUI

struct DebugNotifButton: View {
    var body: some View {
        Button("DEBUG: Ask for Notifications") {
            Task {
                let center = UNUserNotificationCenter.current()
                do {
                    let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                    print("🔔 requestAuthorization returned: \(granted)")
                    let settings = await center.notificationSettings()
                    print("🔧 auth=\(settings.authorizationStatus.rawValue) alert=\(settings.alertSetting.rawValue) sound=\(settings.soundSetting.rawValue)")
                } catch {
                    print("❌ requestAuthorization error: \(error)")
                }
            }
        }
    }
}
