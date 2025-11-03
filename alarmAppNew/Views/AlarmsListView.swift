//
//  AlarmsListView.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/24/25.
//

import SwiftUI
import UserNotifications

struct AlarmsListView: View {

  @Environment(\.scenePhase) private var scenePhase
  @EnvironmentObject private var router: AppRouter
  @StateObject private var vm: AlarmListViewModel
  @State private var detailVM: AlarmDetailViewModel?
  @State private var showSettings = false

  // Store container for child views
  private let container: DependencyContainer

  // Primary initializer - accepts injected container
  init(container: DependencyContainer) {
        self.container = container
        _vm = StateObject(wrappedValue: container.makeAlarmListViewModel())
    }

    // For testing/preview purposes with a pre-configured view model
    init(preConfiguredVM: AlarmListViewModel, container: DependencyContainer) {
        self.container = container
        _vm = StateObject(wrappedValue: preConfiguredVM)
    }

  var body: some View {
    NavigationStack {
      ZStack {
        // Empty state
        if vm.alarms.isEmpty {
          ContentUnavailableView(
            "No Alarms",
            systemImage: "alarm",
            description: Text("Tap + to create your first alarm")
          )
        }

        // Alarm list
        List {
          // Permission warning section
          if let permissionDetails = vm.notificationPermissionDetails {
            Section {
              NotificationPermissionInlineWarning(
                permissionDetails: permissionDetails,
                permissionService: container.permissionService
              )
            }
          }

          // Media volume warning banner
          if vm.showMediaVolumeWarning {
            Section {
              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  Image(systemName: "speaker.wave.1")
                    .foregroundColor(.orange)
                  Text("Low Media Volume Detected")
                    .font(.headline)
                    .foregroundColor(.orange)
                }

                Text("Your media volume is low. This won't affect lock-screen alarms (they use ringer volume), but in-app sounds may be quiet.")
                  .font(.caption)
                  .foregroundColor(.secondary)

                Button("Dismiss") {
                  vm.showMediaVolumeWarning = false
                }
                .font(.caption)
                .foregroundColor(.accentColor)
              }
              .padding(.vertical, 4)
            }
          }

          ForEach(vm.alarms) { alarm in
            AlarmRowView(
              alarm: alarm,
              onToggle: { vm.toggle(alarm) },
              onTap: { detailVM = AlarmDetailViewModel(alarm: alarm, isNew: false) }
            )
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
              Button(role: .destructive) {
                vm.delete(alarm)
              } label: {
                Label("Delete", systemImage: "trash")
              }

              Button {
                detailVM = AlarmDetailViewModel(alarm: alarm, isNew: false)
              } label: {
                Label("Edit", systemImage: "pencil")
              }
              .tint(.blue)
            }
          }
        }
        .listStyle(.insetGrouped)

        // Floating Action Button
        VStack {
          Spacer()
          HStack {
            Spacer()
            Button {
              detailVM = container.makeAlarmDetailViewModel()
            } label: {
              Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.accentColor))
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .accessibilityLabel("Create new alarm")
            .accessibilityHint("Opens alarm creation form")
            .padding(.trailing, 20)
            .padding(.bottom, 20)
          }
        }
      }
      .navigationTitle("Alarms")
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Menu {
            Button("Request Notification Permission", systemImage: "bell.badge") {
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

            Button("Test Lock Screen Notification", systemImage: "lock.circle") {
              Task {
                try? await container.notificationService.scheduleTestSystemDefault()
              }
            }

            Button("Test Lock-Screen Alarm (8s)", systemImage: "bell.badge.fill") {
              vm.testLockScreen()
            }

            Button("Run Sound Triage", systemImage: "stethoscope") {
              Task {
                try? await container.notificationService.runCompleteSoundTriage()
              }
            }

            Button("Bare Default Test", systemImage: "exclamationmark.triangle") {
              Task {
                try? await container.notificationService.scheduleBareDefaultTest()
              }
            }

            Button("Bare Test (No Interruption)", systemImage: "bell.slash") {
              Task {
                try? await container.notificationService.scheduleBareDefaultTestNoInterruption()
              }
            }

            Button("Bare Test (No Category)", systemImage: "bell.badge") {
              Task {
                try? await container.notificationService.scheduleBareDefaultTestNoCategory()
              }
            }

            Divider()

            Button("Settings", systemImage: "gear") {
              showSettings = true
            }
          } label: {
            Image(systemName: "wrench.and.screwdriver")
          }
        }
      }
      .task {
          vm.refreshPermission()
        vm.ensureNotificationPermissionIfNeeded()
      // initial fetch when the screen appears
      }
      .onChange(of: scenePhase) { phase in
          if phase == .active {               // returning from Settings or prompt
              vm.refreshPermission()

              // Check for active alarms and route to ringing if needed
              Task {
                  if let (alarm, _) = await container.activeAlarmDetector.checkForActiveAlarm() {
                      print("📱 AlarmsListView: Auto-routing to ringing for alarm \(alarm.id.uuidString.prefix(8))")
                      router.showRinging(for: alarm.id, intentAlarmID: nil)
                  }
              }
          }
      }

    }
    .sheet(item: $detailVM) { formVM in
      AlarmFormView(detailVM: formVM, container: container) {
        if formVM.isNewAlarm {
          let newAlarm = formVM.commitChanges()
          vm.add(newAlarm)
        } else {
          vm.update(formVM.commitChanges())
        }
        detailVM = nil
      }
    }
    .sheet(isPresented: $vm.showPermissionBlocking) {
      NotificationPermissionBlockingView(
        permissionService: container.permissionService,
        onPermissionGranted: {
          vm.handlePermissionGranted()
        }
      )
    }
    // Note: .alarmDidFire notification removed with NotificationService migration to AlarmKit
    // AlarmKit handles alarm firing via intents and the activeAlarmDetector checks on app foreground
    .sheet(isPresented: $showSettings) {
      SettingsView(container: container)
    }
  }
}

// Separate row view for better organization
struct AlarmRowView: View {
  let alarm: Alarm
  let onToggle: () -> Void
  let onTap: () -> Void

  var body: some View {
    Button {
      onTap()
    } label: {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(alarm.time, style: .time)
            .font(.largeTitle)
            .fontWeight(.light)

          HStack {
            Text(alarm.label)
              .font(.subheadline)
              .foregroundColor(.secondary)

            if !alarm.repeatDays.isEmpty {
              Text("•")
                .foregroundColor(.secondary)
              Text(alarm.repeatDaysText)
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        }

        Spacer()

        Toggle("", isOn: Binding(
          get: { alarm.isEnabled },
          set: { _ in onToggle() }
        ))
        .labelsHidden()
        .accessibilityLabel("\(alarm.isEnabled ? "Disable" : "Enable") alarm for \(alarm.time, style: .time)")
      }
      .padding(.vertical, 8)
    }
    .buttonStyle(.plain)
  }
}

#Preview {
    let container = DependencyContainer()
    let vm = container.makeAlarmListViewModel()

    vm.alarms = [
        Alarm(id: UUID(), time: Date(), label: "Morning", repeatDays: [.monday], challengeKind: [], isEnabled: true, soundId: "chimes01", volume: 0.5),
        Alarm(id: UUID(), time: Date(), label: "Work", repeatDays: [], challengeKind: [.math], isEnabled: true, soundId: "bells01", volume: 0.7),
        Alarm(id: UUID(), time: Date(), label: "Weekend", repeatDays: [.saturday, .sunday], challengeKind: [], isEnabled: false, soundId: "tone01", volume: 0.8)
    ]

    return AlarmsListView(preConfiguredVM: vm, container: container)
        .environmentObject(AppRouter())
        .environment(\.container, container)
}

