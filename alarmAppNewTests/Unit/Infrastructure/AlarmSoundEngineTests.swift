//
//  AlarmSoundEngineTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/2/25.
//

import XCTest
import Combine
@testable import alarmAppNew

@MainActor
final class AlarmSoundEngineTests: XCTestCase {

    var sut: AlarmSoundEngine!
    var mockReliabilityProvider: MockReliabilityModeProvider!

    override func setUp() async throws {
        sut = AlarmSoundEngine.shared
        mockReliabilityProvider = MockReliabilityModeProvider()
        sut.setReliabilityModeProvider(mockReliabilityProvider)

        // Set up policy provider for new capability-based architecture
        sut.setPolicyProvider { [weak self] in
            let mode = self?.mockReliabilityProvider.currentMode ?? .notificationsOnly
            switch mode {
            case .notificationsOnly:
                return AudioPolicy(capability: .foregroundAssist, allowRouteOverrideAtAlarm: true)
            case .notificationsPlusAudio:
                return AudioPolicy(capability: .sleepMode, allowRouteOverrideAtAlarm: true)
            }
        }

        sut.stop() // Ensure clean state
    }

    override func tearDown() async throws {
        sut.stop()
        sut = nil
        mockReliabilityProvider = nil
    }

    // MARK: - isActivelyRinging Property Tests

    func test_isActivelyRinging_falseWhenIdle() {
        // Given: engine in idle state
        sut.stop()

        // Then: should not be actively ringing
        XCTAssertFalse(sut.isActivelyRinging, "Should not be ringing when idle")
        XCTAssertEqual(sut.currentState, .idle)
    }

    func test_isActivelyRinging_falseWhenPrewarming() throws {
        // Given: notificationsPlusAudio mode
        mockReliabilityProvider.setMode(.notificationsPlusAudio)

        // When: schedule prewarm for future (will transition to prewarming)
        let future = Date().addingTimeInterval(30)
        try sut.schedulePrewarm(fireAt: future, soundName: "ringtone1")

        // Then: should not be actively ringing (only prewarming)
        XCTAssertFalse(sut.isActivelyRinging, "Should not be ringing when prewarming")
        XCTAssertEqual(sut.currentState, .prewarming)
    }

    func test_isActivelyRinging_trueWhenRinging() throws {
        // Given: notificationsPlusAudio mode
        mockReliabilityProvider.setMode(.notificationsPlusAudio)

        // When: play foreground alarm (transitions to ringing)
        try sut.playForegroundAlarm(soundName: "ringtone1")

        // Then: should be actively ringing
        XCTAssertTrue(sut.isActivelyRinging, "Should be ringing after playForegroundAlarm")
        XCTAssertEqual(sut.currentState, .ringing)

        // Cleanup
        sut.stop()
    }

    // MARK: - scheduleWithLeadIn Validation Tests

    func test_scheduleWithLeadIn_skipsInNotificationsOnlyMode() throws {
        // Given: notifications-only mode
        mockReliabilityProvider.setMode(.notificationsOnly)

        // When: attempt to schedule with lead-in
        let future = Date().addingTimeInterval(30)
        try sut.scheduleWithLeadIn(fireAt: future, soundId: "ringtone1", leadInSeconds: 5)

        // Then: should remain idle (skipped due to mode)
        XCTAssertEqual(sut.currentState, .idle, "Should skip scheduling in notifications-only mode")
        XCTAssertFalse(sut.isActivelyRinging)
    }

    func test_scheduleWithLeadIn_fallsBackToImmediateIfLeadInExceedsDelta() throws {
        // Given: notificationsPlusAudio mode
        mockReliabilityProvider.setMode(.notificationsPlusAudio)

        // When: lead-in (10s) exceeds delta (3s) - should fall back to immediate
        let nearFuture = Date().addingTimeInterval(3)
        try sut.scheduleWithLeadIn(fireAt: nearFuture, soundId: "ringtone1", leadInSeconds: 10)

        // Then: should have fallen back to immediate playback (ringing state)
        XCTAssertTrue(sut.isActivelyRinging, "Should fall back to immediate when leadIn > delta")
        XCTAssertEqual(sut.currentState, .ringing)

        // Cleanup
        sut.stop()
    }

    func test_scheduleWithLeadIn_schedulesAudioStartCorrectly() throws {
        // Given: notificationsPlusAudio mode
        mockReliabilityProvider.setMode(.notificationsPlusAudio)

        // When: schedule with valid lead-in
        let future = Date().addingTimeInterval(30)
        try sut.scheduleWithLeadIn(fireAt: future, soundId: "ringtone1", leadInSeconds: 5)

        // Then: should transition to prewarming (audio will start at T-5s)
        XCTAssertEqual(sut.currentState, .prewarming, "Should be in prewarming state")
        XCTAssertFalse(sut.isActivelyRinging, "Should not be ringing yet")

        // Cleanup
        sut.stop()
    }

    func test_scheduleWithLeadIn_transitionsToPrewarmingState() throws {
        // Given: notificationsPlusAudio mode and idle state
        mockReliabilityProvider.setMode(.notificationsPlusAudio)
        XCTAssertEqual(sut.currentState, .idle)

        // When: schedule with lead-in
        let future = Date().addingTimeInterval(20)
        try sut.scheduleWithLeadIn(fireAt: future, soundId: "ringtone1", leadInSeconds: 3)

        // Then: state should be prewarming
        XCTAssertEqual(sut.currentState, .prewarming)

        // Cleanup
        sut.stop()
    }

    func test_scheduleWithLeadIn_respectsIdleStateGuard() throws {
        // Given: notificationsPlusAudio mode and already ringing
        mockReliabilityProvider.setMode(.notificationsPlusAudio)
        try sut.playForegroundAlarm(soundName: "ringtone1")
        XCTAssertEqual(sut.currentState, .ringing)

        // When: attempt to schedule with lead-in (should be rejected by state guard)
        let future = Date().addingTimeInterval(30)
        try sut.scheduleWithLeadIn(fireAt: future, soundId: "ringtone1", leadInSeconds: 5)

        // Then: should remain in ringing state (guard rejected the call)
        XCTAssertEqual(sut.currentState, .ringing, "Should ignore scheduleWithLeadIn when not idle")

        // Cleanup
        sut.stop()
    }
}
