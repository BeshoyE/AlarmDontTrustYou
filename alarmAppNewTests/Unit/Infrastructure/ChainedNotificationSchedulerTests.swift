//
//  ChainedNotificationSchedulerTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/1/25.
//

import XCTest
import UserNotifications
@testable import alarmAppNew

final class ChainedNotificationSchedulerTests: XCTestCase {

    private var mockNotificationCenter: MockNotificationCenter!
    private var mockSoundCatalog: MockSoundCatalog!
    private var testNotificationIndex: NotificationIndex!
    private var chainPolicy: ChainPolicy!
    private var mockGlobalLimitGuard: MockGlobalLimitGuard!
    private var mockClock: MockClock!
    private var scheduler: ChainedNotificationScheduler!

    private let testAlarmId = UUID()
    private let testFireDate = Date(timeIntervalSince1970: 1696156800) // Fixed for reproducibility

    override func setUp() {
        super.setUp()

        mockNotificationCenter = MockNotificationCenter()
        mockSoundCatalog = MockSoundCatalog()

        let testSuiteName = "test-scheduler-\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: testSuiteName)!
        testNotificationIndex = NotificationIndex(defaults: testDefaults)

        let settings = ChainSettings(
            maxChainCount: 5,
            ringWindowSec: 300,
            fallbackSpacingSec: 30,
            minLeadTimeSec: 10
        )
        chainPolicy = ChainPolicy(settings: settings)

        mockGlobalLimitGuard = MockGlobalLimitGuard()
        mockClock = MockClock(fixedNow: testFireDate.addingTimeInterval(-3600)) // 1 hour before

        scheduler = ChainedNotificationScheduler(
            notificationCenter: mockNotificationCenter,
            soundCatalog: mockSoundCatalog,
            notificationIndex: testNotificationIndex,
            chainPolicy: chainPolicy,
            globalLimitGuard: mockGlobalLimitGuard,
            clock: mockClock
        )
    }

    override func tearDown() {
        mockNotificationCenter = nil
        mockSoundCatalog = nil
        testNotificationIndex = nil
        chainPolicy = nil
        mockGlobalLimitGuard = nil
        mockClock = nil
        scheduler = nil
        super.tearDown()
    }

    // MARK: - Permission Tests

    func test_scheduleChain_unauthorizedNotifications_returnsUnavailable() async {
        let alarm = createTestAlarm()
        mockNotificationCenter.authorizationStatus = .denied

        let outcome = await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)

        XCTAssertEqual(outcome, .unavailable(reason: .permissions))
        XCTAssertEqual(mockGlobalLimitGuard.reserveCallCount, 0)
        XCTAssertEqual(mockNotificationCenter.scheduledRequests.count, 0)
    }

    func test_scheduleChain_provisionalNotifications_returnsUnavailable() async {
        let alarm = createTestAlarm()
        mockNotificationCenter.authorizationStatus = .provisional

        let outcome = await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)

        XCTAssertEqual(outcome, .unavailable(reason: .permissions))
    }

    // MARK: - Global Limit Tests

    func test_scheduleChain_noAvailableSlots_returnsUnavailable() async {
        let alarm = createTestAlarm()
        mockNotificationCenter.authorizationStatus = .authorized
        mockGlobalLimitGuard.reserveReturnValue = 0

        let outcome = await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)

        XCTAssertEqual(outcome, .unavailable(reason: .globalLimit))
        XCTAssertEqual(mockGlobalLimitGuard.reserveCallCount, 1)
        XCTAssertEqual(mockGlobalLimitGuard.finalizeCallCount, 1)
        XCTAssertEqual(mockNotificationCenter.scheduledRequests.count, 0)
    }

    func test_scheduleChain_partialSlots_returnsTrimmed() async {
        let alarm = createTestAlarm()
        mockNotificationCenter.authorizationStatus = .authorized
        mockSoundCatalog.soundInfo = SoundInfo(name: "test", fileName: "test.caf", durationSec: 30)
        mockGlobalLimitGuard.reserveReturnValue = 3 // Less than the 5 requested

        let outcome = await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)

        if case .trimmed(let original, let scheduled) = outcome {
            XCTAssertEqual(original, 5) // maxChainCount from settings
            XCTAssertEqual(scheduled, 3) // limited by available slots
        } else {
            XCTFail("Expected trimmed outcome, got \(outcome)")
        }

        XCTAssertEqual(mockNotificationCenter.scheduledRequests.count, 3)
        XCTAssertEqual(mockGlobalLimitGuard.finalizeCallCount, 1)
    }

    // MARK: - Successful Scheduling Tests

    func test_scheduleChain_fullSlots_returnsScheduled() async {
        let alarm = createTestAlarm()
        mockNotificationCenter.authorizationStatus = .authorized
        mockSoundCatalog.soundInfo = SoundInfo(name: "test", fileName: "test.caf", durationSec: 30)
        mockGlobalLimitGuard.reserveReturnValue = 5

        let outcome = await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)

        if case .scheduled(let count) = outcome {
            XCTAssertEqual(count, 5)
        } else {
            XCTFail("Expected scheduled outcome, got \(outcome)")
        }

        XCTAssertEqual(mockNotificationCenter.scheduledRequests.count, 5)
        XCTAssertEqual(mockGlobalLimitGuard.finalizeCallCount, 1)
    }

    func test_scheduleChain_correctFireDatesSpacing() async {
        let alarm = createTestAlarm()
        mockNotificationCenter.authorizationStatus = .authorized
        mockSoundCatalog.soundInfo = SoundInfo(name: "test", fileName: "test.caf", durationSec: 45)
        mockGlobalLimitGuard.reserveReturnValue = 3

        await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)

        let requests = mockNotificationCenter.scheduledRequests
        XCTAssertEqual(requests.count, 3)

        // Verify spacing matches sound duration
        for (index, request) in requests.enumerated() {
            if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                let expectedFireDate = testFireDate.addingTimeInterval(Double(index * 45))
                let calendar = Calendar.current
                let expectedComponents = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second],
                    from: expectedFireDate
                )

                XCTAssertEqual(trigger.dateComponents.year, expectedComponents.year)
                XCTAssertEqual(trigger.dateComponents.hour, expectedComponents.hour)
                XCTAssertEqual(trigger.dateComponents.minute, expectedComponents.minute)
            } else {
                XCTFail("Expected calendar trigger for request \(index)")
            }
        }
    }

    // MARK: - Sound Catalog Integration Tests

    func test_scheduleChain_fallbackSoundDuration_usesFallbackSpacing() async {
        let alarm = createTestAlarm()
        mockNotificationCenter.authorizationStatus = .authorized
        mockSoundCatalog.soundInfo = nil // No sound info found
        mockGlobalLimitGuard.reserveReturnValue = 3

        await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)

        let requests = mockNotificationCenter.scheduledRequests
        XCTAssertEqual(requests.count, 3)

        // Should use fallback spacing of 30 seconds
        if let firstTrigger = requests[0].trigger as? UNCalendarNotificationTrigger,
           let secondTrigger = requests[1].trigger as? UNCalendarNotificationTrigger {

            let firstDate = Calendar.current.date(from: firstTrigger.dateComponents)!
            let secondDate = Calendar.current.date(from: secondTrigger.dateComponents)!
            let actualSpacing = secondDate.timeIntervalSince(firstDate)

            XCTAssertEqual(actualSpacing, 30.0, accuracy: 1.0)
        }
    }

    // MARK: - Notification Content Tests

    func test_scheduleChain_notificationContent_correctFormat() async {
        let alarm = createTestAlarm(label: "Morning Workout")
        mockNotificationCenter.authorizationStatus = .authorized
        mockSoundCatalog.soundInfo = SoundInfo(name: "gentle", fileName: "gentle.caf", durationSec: 20)
        mockGlobalLimitGuard.reserveReturnValue = 2

        await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)

        let requests = mockNotificationCenter.scheduledRequests
        XCTAssertEqual(requests.count, 2)

        for request in requests {
            XCTAssertEqual(request.content.title, "Alarm")
            XCTAssertEqual(request.content.body, "Morning Workout")
            XCTAssertEqual(request.content.categoryIdentifier, "ALARM_CATEGORY")

            if let sound = request.content.sound {
                XCTAssertEqual(sound.description, "UNNotificationSound:gentle.caf")
            } else {
                XCTFail("Expected notification sound")
            }
        }
    }

    func test_scheduleChain_emptyLabel_usesDefaultBody() async {
        let alarm = createTestAlarm(label: "")
        mockNotificationCenter.authorizationStatus = .authorized
        mockGlobalLimitGuard.reserveReturnValue = 1

        await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)

        let request = mockNotificationCenter.scheduledRequests.first!
        XCTAssertEqual(request.content.body, "Alarm")
    }

    // MARK: - Identifier Tests

    func test_scheduleChain_identifierFormat_isCorrect() async {
        let alarm = createTestAlarm()
        mockNotificationCenter.authorizationStatus = .authorized
        mockGlobalLimitGuard.reserveReturnValue = 2

        await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)

        let requests = mockNotificationCenter.scheduledRequests
        XCTAssertEqual(requests.count, 2)

        for (index, request) in requests.enumerated() {
            XCTAssertTrue(request.identifier.hasPrefix("alarm-\(alarm.id.uuidString)-occ-"))
            XCTAssertTrue(request.identifier.hasSuffix("-\(index)"))
            XCTAssertTrue(request.identifier.contains("T")) // ISO8601 format
        }
    }

    // MARK: - Idempotent Reschedule Tests

    func test_scheduleChain_existingChain_cancelsBeforeScheduling() async {
        let alarm = createTestAlarm()
        mockNotificationCenter.authorizationStatus = .authorized
        mockGlobalLimitGuard.reserveReturnValue = 2

        // First schedule
        await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)
        XCTAssertEqual(mockNotificationCenter.scheduledRequests.count, 2)
        let firstRequestIds = mockNotificationCenter.scheduledRequests.map(\.identifier)

        // Second schedule with different fire date
        let newFireDate = testFireDate.addingTimeInterval(3600)
        await scheduler.scheduleChain(for: alarm, fireDate: newFireDate)

        // Should have cancelled old and scheduled new
        XCTAssertEqual(mockNotificationCenter.cancelledIdentifiers.count, 2)
        XCTAssertTrue(Set(firstRequestIds).isSubset(of: Set(mockNotificationCenter.cancelledIdentifiers)))
        XCTAssertEqual(mockNotificationCenter.scheduledRequests.count, 2) // New ones
    }

    // MARK: - Cancel Chain Tests

    func test_cancelChain_existingChain_removesAllNotifications() async {
        let alarm = createTestAlarm()
        mockNotificationCenter.authorizationStatus = .authorized
        mockGlobalLimitGuard.reserveReturnValue = 3

        // Schedule chain
        await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)
        XCTAssertEqual(mockNotificationCenter.scheduledRequests.count, 3)

        // Cancel chain
        await scheduler.cancelChain(alarmId: alarm.id)

        XCTAssertEqual(mockNotificationCenter.cancelledIdentifiers.count, 3)
        XCTAssertEqual(testNotificationIndex.loadIdentifiers(alarmId: alarm.id), [])
    }

    func test_cancelChain_nonexistentChain_doesNothing() async {
        let nonexistentAlarmId = UUID()

        await scheduler.cancelChain(alarmId: nonexistentAlarmId)

        XCTAssertEqual(mockNotificationCenter.cancelledIdentifiers.count, 0)
    }

    // MARK: - Authorization Tests

    func test_requestAuthorization_granted_succeeds() async {
        mockNotificationCenter.authorizationGranted = true
        mockNotificationCenter.authorizationError = nil

        do {
            try await scheduler.requestAuthorization()
        } catch {
            XCTFail("Should not throw when authorization is granted")
        }
    }

    func test_requestAuthorization_denied_throws() async {
        mockNotificationCenter.authorizationGranted = false
        mockNotificationCenter.authorizationError = nil

        do {
            try await scheduler.requestAuthorization()
            XCTFail("Should throw when authorization is denied")
        } catch let error as NotificationSchedulingError {
            XCTAssertEqual(error, .authorizationDenied)
        } catch {
            XCTFail("Should throw NotificationSchedulingError.authorizationDenied")
        }
    }

    func test_requestAuthorization_systemError_throws() async {
        let systemError = NSError(domain: "TestError", code: 123, userInfo: nil)
        mockNotificationCenter.authorizationGranted = true
        mockNotificationCenter.authorizationError = systemError

        do {
            try await scheduler.requestAuthorization()
            XCTFail("Should throw when system error occurs")
        } catch {
            XCTAssertEqual(error as NSError, systemError)
        }
    }

    // MARK: - Bug Fix Tests (Timing & Sound)

    func test_buildTriggerWithInterval_usesProvidedInterval() {
        // Given: a specific interval
        let interval: TimeInterval = 45.0

        // When: build trigger with the interval
        let trigger = scheduler.buildTriggerWithInterval(interval)

        // Then: should use time interval trigger with provided interval
        XCTAssertTrue(trigger is UNTimeIntervalNotificationTrigger, "Should use UNTimeIntervalNotificationTrigger for precise timing")

        let timeTrigger = trigger as! UNTimeIntervalNotificationTrigger
        XCTAssertEqual(timeTrigger.timeInterval, 45.0, "Time interval should match provided interval")
        XCTAssertFalse(timeTrigger.repeats, "Alarm triggers should not repeat")
    }

    func test_buildTriggerWithInterval_clampsToIOSMinimum() {
        // Given: interval less than iOS minimum
        let interval: TimeInterval = 0.5

        // When: build trigger with small interval
        let trigger = scheduler.buildTriggerWithInterval(interval)

        // Then: should clamp to iOS minimum (1 second)
        XCTAssertTrue(trigger is UNTimeIntervalNotificationTrigger, "Should use UNTimeIntervalNotificationTrigger")

        let timeTrigger = trigger as! UNTimeIntervalNotificationTrigger
        XCTAssertEqual(timeTrigger.timeInterval, 1.0, "Should clamp to iOS minimum of 1 second")
    }

    func test_buildTriggerWithInterval_preservesSpacing() {
        // Given: base interval and spacing
        let baseInterval: TimeInterval = 10.0
        let spacing: TimeInterval = 15.0

        // When: build triggers for a chain
        let trigger0 = scheduler.buildTriggerWithInterval(baseInterval + 0 * spacing)
        let trigger1 = scheduler.buildTriggerWithInterval(baseInterval + 1 * spacing)
        let trigger2 = scheduler.buildTriggerWithInterval(baseInterval + 2 * spacing)

        // Then: intervals should preserve spacing
        let timeTrigger0 = trigger0 as! UNTimeIntervalNotificationTrigger
        let timeTrigger1 = trigger1 as! UNTimeIntervalNotificationTrigger
        let timeTrigger2 = trigger2 as! UNTimeIntervalNotificationTrigger

        XCTAssertEqual(timeTrigger0.timeInterval, 10.0, "First interval should be base")
        XCTAssertEqual(timeTrigger1.timeInterval, 25.0, "Second interval should be base + spacing")
        XCTAssertEqual(timeTrigger2.timeInterval, 40.0, "Third interval should be base + 2*spacing")
    }

    func test_eachChainedRequest_hasSoundAttached() async {
        // Given: authorized notifications with available slots
        let alarm = createTestAlarm()
        mockNotificationCenter.authorizationStatus = .authorized
        mockGlobalLimitGuard.reserveReturnValue = 5
        mockSoundCatalog.soundInfo = SoundInfo(
            id: "test",
            name: "Test Sound",
            fileName: "test.caf",
            durationSeconds: 10
        )

        // When: schedule chain
        let outcome = await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)

        // Then: all scheduled requests should have sound attached
        guard case .scheduled(let count) = outcome else {
            XCTFail("Expected scheduled outcome")
            return
        }

        XCTAssertEqual(count, 5, "Should schedule all reserved slots")
        XCTAssertEqual(mockNotificationCenter.scheduledRequests.count, 5, "Should have 5 requests in notification center")

        // Verify every request has sound
        for request in mockNotificationCenter.scheduledRequests {
            XCTAssertNotNil(request.content.sound, "Every alarm notification must have sound attached")
        }
    }

    // MARK: - Helper Methods

    private func createTestAlarm(label: String = "Test Alarm") -> Alarm {
        return Alarm(
            id: testAlarmId,
            time: DateComponents(hour: 7, minute: 30),
            repeatDays: [],
            label: label,
            soundId: "test-sound",
            volume: 0.8,
            vibrate: true,
            isEnabled: true
        )
    }
}

// MARK: - Mock Implementations

private class MockNotificationCenter: UNUserNotificationCenter {
    var authorizationStatus: UNAuthorizationStatus = .authorized
    var authorizationGranted = true
    var authorizationError: Error?
    var scheduledRequests: [UNNotificationRequest] = []
    var cancelledIdentifiers: [String] = []

    override func notificationSettings() async -> UNNotificationSettings {
        let settings = MockNotificationSettings(authorizationStatus: authorizationStatus)
        return settings
    }

    override func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        if let error = authorizationError {
            throw error
        }
        return authorizationGranted
    }

    override func add(_ request: UNNotificationRequest) async throws {
        scheduledRequests.append(request)
    }

    override func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        cancelledIdentifiers.append(contentsOf: identifiers)
    }

    override func pendingNotificationRequests() async -> [UNNotificationRequest] {
        return scheduledRequests
    }
}

private class MockNotificationSettings: UNNotificationSettings {
    private let _authorizationStatus: UNAuthorizationStatus

    init(authorizationStatus: UNAuthorizationStatus) {
        self._authorizationStatus = authorizationStatus
        super.init()
    }

    override var authorizationStatus: UNAuthorizationStatus {
        return _authorizationStatus
    }
}

private class MockSoundCatalog: SoundCatalogProviding {
    var soundInfo: SoundInfo?

    func safeInfo(for soundId: String) -> SoundInfo? {
        return soundInfo
    }
}

private class MockGlobalLimitGuard: GlobalLimitGuard {
    var reserveReturnValue: Int = 0
    var reserveCallCount = 0
    var finalizeCallCount = 0

    override func reserve(_ count: Int) async -> Int {
        reserveCallCount += 1
        return reserveReturnValue
    }

    override func finalize(_ actualScheduled: Int) {
        finalizeCallCount += 1
    }
}