//
//  AlarmsListView.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/24/25.
//

import SwiftUI

struct AlarmsListView: View {

  @EnvironmentObject private var router: AppRouter
  @StateObject private var vm: AlarmListViewModel
  @State private var detailVM: AlarmDetailViewModel?

  init() {
        _vm = StateObject(wrappedValue: AlarmListViewModel())
    }

    // For testing/preview purposes with a pre-configured view model
    init(preConfiguredVM: AlarmListViewModel) {
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
          ForEach(vm.alarms) { alarm in
            AlarmRowView(alarm: alarm) {
                router.showDismissal(for: alarm.id)
            }
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
              detailVM = AlarmDetailViewModel(alarm: .blank, isNew: true)
            } label: {
              Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.accentColor))
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
          }
        }
      }
      .navigationTitle("Alarms")
    }
    .sheet(item: $detailVM) { formVM in
      AlarmFormView(detailVM: formVM) {
        if formVM.isNewAlarm {
          let newAlarm = formVM.commitChanges()
          vm.add(newAlarm)
        } else {
          vm.update(formVM.commitChanges())
        }
        detailVM = nil
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .alarmDidFire)) { note in
                if let id = note.object as? UUID {
                    router.showDismissal(for: id)
                }
            }
  }
}

// Separate row view for better organization
struct AlarmRowView: View {
  let alarm: Alarm
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

        Toggle("", isOn: .constant(alarm.isEnabled))
          .labelsHidden()
          .allowsHitTesting(false)
      }
      .padding(.vertical, 8)
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  let previewVM = AlarmListViewModel()
  previewVM.alarms = [
    Alarm(id: UUID(), time: Date(), label: "Morning", repeatDays: [.monday], challengeKind: [], isEnabled: true),
    Alarm(id: UUID(), time: Date(), label: "Work", repeatDays: [], challengeKind: [.math], isEnabled: true),
    Alarm(id: UUID(), time: Date(), label: "Weekend", repeatDays: [.saturday, .sunday], challengeKind: [], isEnabled: false)
  ]

  return AlarmsListView(preConfiguredVM: previewVM)
    .environmentObject(AppRouter())
}

