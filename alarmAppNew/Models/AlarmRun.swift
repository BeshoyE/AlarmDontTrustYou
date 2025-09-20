
import Foundation

enum AlarmOutcome: String, Codable {
  case success
  case failed
  
}

struct AlarmRun: Identifiable, Equatable, Codable {
  let id: UUID
  let alarmId: UUID
  let firedAt: Date
  var dismissedAt: Date?
  var outcome: AlarmOutcome
  
  // MARK: - Helper Factories
  
  static func fired(alarmId: UUID, at time: Date = Date()) -> AlarmRun {
    AlarmRun(
      id: UUID(),
      alarmId: alarmId,
      firedAt: time,
      dismissedAt: nil,
      outcome: .failed // Default to failed until explicitly dismissed
    )
  }
  
  static func successful(alarmId: UUID, firedAt: Date, dismissedAt: Date) -> AlarmRun {
    AlarmRun(
      id: UUID(),
      alarmId: alarmId,
      firedAt: firedAt,
      dismissedAt: dismissedAt,
      outcome: .success
    )
  }
  
  static func failed(alarmId: UUID, firedAt: Date) -> AlarmRun {
    AlarmRun(
      id: UUID(),
      alarmId: alarmId,
      firedAt: firedAt,
      dismissedAt: nil,
      outcome: .failed
    )
  }
  
  // MARK: - Mutations
  
  mutating func markDismissed(at time: Date = Date()) {
    dismissedAt = time
    outcome = .success
  }
  
  mutating func markFailed() {
    outcome = .failed
    dismissedAt = nil
  }
}


