//
//  SettingsView.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/24/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settingsService: SettingsService
    @Environment(\.dismiss) private var dismiss

    init(container: DependencyContainer) {
        self.settingsService = container.settingsServiceConcrete
    }

    var body: some View {
        NavigationStack {
            Form {
                // General Settings Section
                Section("General") {
                    Text("App version and basic settings would go here in a full implementation")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }

#if DEBUG
                // Developer Section - Only visible in DEBUG builds
                Section("Developer Settings") {
                    VStack(alignment: .leading, spacing: 12) {
                        // Reliability Mode Toggle
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Experimental: Background Audio Reliability")
                                    .font(.headline)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { settingsService.currentMode == .notificationsPlusAudio },
                                    set: { isOn in
                                        let newMode: ReliabilityMode = isOn ? .notificationsPlusAudio : .notificationsOnly
                                        settingsService.setReliabilityMode(newMode)
                                    }
                                ))
                                .labelsHidden()
                            }

                            Text(settingsService.currentMode.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Warning Message
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Developer Warning")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                            }

                            Text("Background audio mode is experimental and may not be App Store compliant. Use only for testing purposes. Default 'Notifications Only' mode is App Store safe.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)

                        // Current Mode Status
                        HStack {
                            Text("Current Mode:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(settingsService.currentMode.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(settingsService.currentMode == .notificationsOnly ? .green : .orange)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .headerProminence(.increased)
#endif

                // Reset Section
                Section("Reset") {
                    Button("Reset to Defaults") {
                        settingsService.resetToDefaults()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let container = DependencyContainer()
    return SettingsView(container: container)
}