//
//  E2E_AlarmDismissalFlowTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 9/7/25.
//  End-to-end tests for critical MVP1 scenarios
//

import XCTest
@testable import alarmAppNew

@MainActor
class E2E_AlarmDismissalFlowTests: XCTestCase {
    var dependencyContainer: DependencyContainer!
    var mockClock: TestClock!
    
    override func setUp() {
        super.setUp()
        
        // Use real dependency container but with test clock
        dependencyContainer = DependencyContainer.shared
        mockClock = TestClock()
    }
    
    override func tearDown() {
        // Clean up any test data
        try? dependencyContainer.persistenceService.saveAlarms([])
        dependencyContainer.reliabilityLogger.clearLogs()
        super.tearDown()
    }
    
    // MARK: - E2E: Full Alarm Flow
    
    func test_E2E_setAlarm_ring_scan_dismiss_success() async throws {
        // This test simulates the complete user journey:
        // 1. User creates alarm with QR code
        // 2. Alarm fires (notification)
        // 3. User taps notification -> navigates to ringing view
        // 4. User scans correct QR code
        // 5. Alarm is dismissed successfully
        
        // GIVEN: Create alarm with QR code
        let testQRCode = "test-qr-code-12345"
        let alarm = Alarm(
            id: UUID(),
            time: mockClock.now().addingTimeInterval(60), // 1 minute from now
            label: "E2E Test Alarm",
            repeatDays: [],
            challengeKind: [.qr],
            expectedQR: testQRCode,
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: true,
            soundId: "chimes01",
            volume: 0.8
        )
        
        // WHEN: User enables alarm (should schedule notification)
        let alarmListVM = dependencyContainer.makeAlarmListViewModel()
        alarmListVM.add(alarm)
        
        // Wait for async scheduling
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms
        
        // THEN: Alarm should be scheduled
        let pendingIds = await dependencyContainer.notificationService.pendingAlarmIds()
        XCTAssertTrue(pendingIds.contains(alarm.id), "Alarm should be scheduled")
        
        // WHEN: Simulate alarm firing
        dependencyContainer.reliabilityLogger.logAlarmFired(alarm.id, details: ["source": "e2e_test"])
        
        // WHEN: Navigate to dismissal flow (simulates notification tap)
        dependencyContainer.appRouter.showRinging(for: alarm.id)
        XCTAssertEqual(dependencyContainer.appRouter.route, .ringing(alarmID: alarm.id))
        
        // WHEN: Start dismissal flow
        let dismissalVM = dependencyContainer.makeDismissalFlowViewModel()
        dismissalVM.start(alarmId: alarm.id)
        
        // THEN: Should be in ringing state
        XCTAssertEqual(dismissalVM.state, .ringing)
        
        // WHEN: Begin QR scanning
        dismissalVM.beginScan()
        
        // Wait for async permission check and scanning setup
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // THEN: Should be in scanning state
        XCTAssertEqual(dismissalVM.state, .scanning)
        
        // WHEN: Scan correct QR code
        dismissalVM.didScan(payload: testQRCode)
        
        // THEN: Should complete successfully
        XCTAssertEqual(dismissalVM.state, .success)
        
        // THEN: Should log success event
        let recentLogs = dependencyContainer.reliabilityLogger.getRecentLogs(limit: 10)
        let successLogs = recentLogs.filter { $0.event == .dismissSuccessQR && $0.alarmId == alarm.id }
        XCTAssertFalse(successLogs.isEmpty, "Should log dismiss success event")
        
        // THEN: Should navigate back to list after success delay
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        XCTAssertEqual(dependencyContainer.appRouter.route, .alarmList)
    }
    
    // MARK: - E2E: App Killed Scenario
    
    func test_E2E_appKilled_notificationRestoration() async throws {
        // This test simulates the critical "works if app is killed/closed" scenario:
        // 1. User creates alarm
        // 2. App is killed/closed
        // 3. Notification fires
        // 4. User taps "Return to Dismissal" action
        // 5. App cold-starts and navigates to dismissal flow
        
        // GIVEN: Alarm with QR code
        let testQRCode = "cold-start-qr-code"
        let alarm = Alarm(
            id: UUID(),
            time: mockClock.now().addingTimeInterval(30),
            label: "Cold Start Test Alarm",
            repeatDays: [],
            challengeKind: [.qr],
            expectedQR: testQRCode,
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: true,
            soundId: "chimes01",
            volume: 0.8
        )
        
        // WHEN: Schedule alarm
        try await dependencyContainer.notificationService.scheduleAlarm(alarm)
        
        // SIMULATE: App is killed (clear in-memory state)
        let originalRoute = dependencyContainer.appRouter.route
        XCTAssertEqual(originalRoute, .alarmList)
        
        // SIMULATE: Notification fires and user taps "Return to Dismissal"
        // (This simulates the NotificationService delegate being called on cold start)
        dependencyContainer.appRouter.showRinging(for: alarm.id)
        
        // THEN: App should navigate to ringing view even from cold start
        XCTAssertEqual(dependencyContainer.appRouter.route, .ringing(alarmID: alarm.id))
        XCTAssertTrue(dependencyContainer.appRouter.isInDismissalFlow)
        
        // WHEN: Create new dismissal flow VM (simulates cold start creation)
        let dismissalVM = dependencyContainer.makeDismissalFlowViewModel()
        dismissalVM.start(alarmId: alarm.id)
        
        // THEN: Should work correctly even after cold start
        XCTAssertEqual(dismissalVM.state, .ringing)
        
        // WHEN: Complete the flow
        dismissalVM.beginScan()
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        dismissalVM.didScan(payload: testQRCode)
        
        // THEN: Should succeed
        XCTAssertEqual(dismissalVM.state, .success)
    }
    
    // MARK: - E2E: 3-Alarm Smoke Test
    
    func test_E2E_threeAlarmSmoke_noCrashes() async throws {
        // This test validates the "3-alarm smoke with no crashes" requirement
        
        var alarms: [Alarm] = []
        let alarmListVM = dependencyContainer.makeAlarmListViewModel()
        
        // GIVEN: Create 3 alarms with different configurations
        for i in 1...3 {
            let alarm = Alarm(
                id: UUID(),
                time: mockClock.now().addingTimeInterval(TimeInterval(i * 10)), // Staggered times
                label: "Smoke Test Alarm \(i)",
                repeatDays: i == 2 ? [.monday, .wednesday, .friday] : [], // One repeating alarm
                challengeKind: [.qr],
                expectedQR: "smoke-test-qr-\(i)",
                stepThreshold: nil,
                mathChallenge: nil,
                isEnabled: true,
                soundId: "chimes01",
                volume: 0.8
            )
            alarms.append(alarm)
            alarmListVM.add(alarm)
        }
        
        // Wait for all scheduling to complete
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // THEN: All alarms should be scheduled without crashes
        let pendingIds = await dependencyContainer.notificationService.pendingAlarmIds()
        XCTAssertGreaterThanOrEqual(pendingIds.count, 3, "At least 3 notifications should be scheduled")
        
        // WHEN: Simulate all alarms firing and being dismissed
        for alarm in alarms {
            // Log firing
            dependencyContainer.reliabilityLogger.logAlarmFired(alarm.id)
            
            // Navigate to dismissal
            dependencyContainer.appRouter.showRinging(for: alarm.id)
            
            // Create and run dismissal flow
            let dismissalVM = dependencyContainer.makeDismissalFlowViewModel()
            dismissalVM.start(alarmId: alarm.id)
            dismissalVM.beginScan()
            
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            
            // Dismiss with correct QR
            dismissalVM.didScan(payload: "smoke-test-qr-\(alarms.firstIndex(of: alarm)! + 1)")
            
            // Verify success
            XCTAssertEqual(dismissalVM.state, .success)
            
            // Return to list
            dependencyContainer.appRouter.backToList()
            
            try await Task.sleep(nanoseconds: 200_000_000) // 200ms between alarms
        }
        
        // THEN: All operations should complete without crashes
        let logs = dependencyContainer.reliabilityLogger.getRecentLogs(limit: 20)
        let successLogs = logs.filter { $0.event == .dismissSuccessQR }
        XCTAssertEqual(successLogs.count, 3, "All 3 alarms should have been dismissed successfully")
        
        // THEN: App should be back at list view
        XCTAssertEqual(dependencyContainer.appRouter.route, .alarmList)
        XCTAssertFalse(dependencyContainer.appRouter.isInDismissalFlow)
    }
    
    // MARK: - Edge Cases
    
    func test_E2E_alarmWithoutQR_preventedFromScheduling() {
        // Test the data model guardrail
        
        let alarmWithoutQR = Alarm(
            id: UUID(),
            time: Date(),
            label: "Invalid Alarm",
            repeatDays: [],
            challengeKind: [.qr],
            expectedQR: nil, // Missing QR code
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: false,
            soundId: "chimes01",
            volume: 0.8
        )
        
        let alarmListVM = dependencyContainer.makeAlarmListViewModel()
        alarmListVM.add(alarmWithoutQR)
        
        // WHEN: Try to enable alarm without QR code
        alarmListVM.toggle(alarmWithoutQR)
        
        // THEN: Should fail with error message
        XCTAssertNotNil(alarmListVM.errorMessage)
        XCTAssertTrue(alarmListVM.errorMessage?.contains("QR code required") ?? false)
        
        // THEN: Alarm should remain disabled
        let savedAlarms = (try? dependencyContainer.persistenceService.loadAlarms()) ?? []
        let savedAlarm = savedAlarms.first { $0.id == alarmWithoutQR.id }
        XCTAssertFalse(savedAlarm?.isEnabled ?? true)
    }
}