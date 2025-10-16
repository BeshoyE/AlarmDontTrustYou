//
//  AlarmStopSemanticsTests.swift
//  alarmAppNewTests
//
//  Tests for the StopAlarmAllowed use case to verify that
//  stop is only allowed after challenge validation.
//

import XCTest
@testable import alarmAppNew

final class AlarmStopSemanticsTests: XCTestCase {

    // MARK: - Stop Disallowed Tests

    func test_stop_disallowed_until_all_challenges_validated() {
        // GIVEN: An alarm with multiple challenges
        let requiredChallenges: [Challenges] = [.qr, .stepCount, .math]

        // WHEN: Only some challenges are completed
        let partiallyCompleteState = ChallengeStackState(
            requiredChallenges: requiredChallenges,
            completedChallenges: [.qr, .stepCount]  // Missing .math
        )

        // THEN: Stop should not be allowed
        XCTAssertFalse(
            StopAlarmAllowed.execute(challengeState: partiallyCompleteState),
            "Stop should not be allowed when challenges remain incomplete"
        )

        // AND: Reason should indicate remaining challenge
        let reason = StopAlarmAllowed.reasonForDenial(challengeState: partiallyCompleteState)
        XCTAssertNotNil(reason, "Should provide reason for denial")
        XCTAssertTrue(
            reason?.contains("Math") ?? false,
            "Reason should mention the remaining challenge"
        )
    }

    func test_stop_disallowed_when_no_challenges_completed() {
        // GIVEN: An alarm with challenges
        let requiredChallenges: [Challenges] = [.qr, .math]

        // WHEN: No challenges are completed
        let uncompleteState = ChallengeStackState(
            requiredChallenges: requiredChallenges,
            completedChallenges: []
        )

        // THEN: Stop should not be allowed
        XCTAssertFalse(
            StopAlarmAllowed.execute(challengeState: uncompleteState),
            "Stop should not be allowed when no challenges are completed"
        )

        // AND: Reason should indicate all challenges need completion
        let reason = StopAlarmAllowed.reasonForDenial(challengeState: uncompleteState)
        XCTAssertEqual(
            reason,
            "Complete all challenges to stop the alarm",
            "Should indicate all challenges need completion"
        )
    }

    func test_stop_disallowed_during_validation() {
        // GIVEN: An alarm with challenges being validated
        let requiredChallenges: [Challenges] = [.qr]

        // WHEN: Challenge is being validated
        let validatingState = ChallengeStackState(
            requiredChallenges: requiredChallenges,
            completedChallenges: [],
            isValidating: true
        )

        // THEN: Stop should not be allowed
        XCTAssertFalse(
            StopAlarmAllowed.execute(challengeState: validatingState),
            "Stop should not be allowed during validation"
        )

        // AND: Reason should indicate validation in progress
        let reason = StopAlarmAllowed.reasonForDenial(challengeState: validatingState)
        XCTAssertEqual(
            reason,
            "Challenge validation in progress",
            "Should indicate validation is in progress"
        )
    }

    // MARK: - Stop Allowed Tests

    func test_stop_allowed_after_validation() {
        // GIVEN: An alarm with challenges
        let requiredChallenges: [Challenges] = [.qr, .stepCount, .math]

        // WHEN: All challenges are completed
        let completeState = ChallengeStackState(
            requiredChallenges: requiredChallenges,
            completedChallenges: Set(requiredChallenges)
        )

        // THEN: Stop should be allowed
        XCTAssertTrue(
            StopAlarmAllowed.execute(challengeState: completeState),
            "Stop should be allowed when all challenges are completed"
        )

        // AND: No reason for denial
        let reason = StopAlarmAllowed.reasonForDenial(challengeState: completeState)
        XCTAssertNil(reason, "Should not provide reason when stop is allowed")
    }

    func test_stop_allowed_when_no_challenges_required() {
        // GIVEN: An alarm with no challenges
        let noChallengesState = ChallengeStackState(
            requiredChallenges: [],
            completedChallenges: []
        )

        // THEN: Stop should be allowed
        XCTAssertTrue(
            StopAlarmAllowed.execute(challengeState: noChallengesState),
            "Stop should be allowed when no challenges are required"
        )
    }

    // MARK: - Alternative Execute Method Tests

    func test_stop_with_alarm_object() throws {
        // GIVEN: An alarm with specific challenges
        let factory = MockAlarmFactory()
        let alarm = factory.makeNewAlarm()
        var modifiedAlarm = alarm
        modifiedAlarm.challengeKind = [.qr, .math]

        // WHEN: Checking with partial completion
        let partialCompletion: Set<Challenges> = [.qr]

        // THEN: Stop should not be allowed
        XCTAssertFalse(
            StopAlarmAllowed.execute(
                alarm: modifiedAlarm,
                completedChallenges: partialCompletion
            ),
            "Stop should not be allowed with partial completion"
        )

        // WHEN: All challenges completed
        let fullCompletion: Set<Challenges> = [.qr, .math]

        // THEN: Stop should be allowed
        XCTAssertTrue(
            StopAlarmAllowed.execute(
                alarm: modifiedAlarm,
                completedChallenges: fullCompletion
            ),
            "Stop should be allowed with full completion"
        )
    }

    // MARK: - Progress Tracking Tests

    func test_challenge_progress_tracking() {
        // GIVEN: Various challenge states
        let requiredChallenges: [Challenges] = [.qr, .stepCount, .math]

        // Test no progress
        let noProgressState = ChallengeStackState(
            requiredChallenges: requiredChallenges,
            completedChallenges: []
        )
        XCTAssertEqual(noProgressState.progress, 0.0, accuracy: 0.01)
        XCTAssertEqual(noProgressState.nextChallenge, .qr)

        // Test partial progress
        let partialState = ChallengeStackState(
            requiredChallenges: requiredChallenges,
            completedChallenges: [.qr]
        )
        XCTAssertEqual(partialState.progress, 1.0/3.0, accuracy: 0.01)
        XCTAssertEqual(partialState.nextChallenge, .stepCount)

        // Test complete progress
        let completeState = ChallengeStackState(
            requiredChallenges: requiredChallenges,
            completedChallenges: Set(requiredChallenges)
        )
        XCTAssertEqual(completeState.progress, 1.0, accuracy: 0.01)
        XCTAssertNil(completeState.nextChallenge)
    }

    func test_challenge_progress_display() {
        // GIVEN: A challenge state
        let state = ChallengeStackState(
            requiredChallenges: [.qr, .math],
            completedChallenges: [.qr]
        )

        // WHEN: Creating progress display
        let progress = ChallengeProgress(state: state)

        // THEN: Display values should be correct
        XCTAssertEqual(progress.total, 2)
        XCTAssertEqual(progress.completed, 1)
        XCTAssertEqual(progress.remaining, 1)
        XCTAssertEqual(progress.percentComplete, 50)
        XCTAssertFalse(progress.isComplete)
        XCTAssertEqual(progress.displayText, "1 of 2 challenges completed")
    }

    func test_estimated_time_until_allowed() {
        // GIVEN: Challenge state with remaining challenges
        let state = ChallengeStackState(
            requiredChallenges: [.qr, .stepCount, .math],
            completedChallenges: [.qr]
        )

        // WHEN: Estimating time with default 10s per challenge
        let estimatedTime = StopAlarmAllowed.estimatedTimeUntilAllowed(
            challengeState: state
        )

        // THEN: Should be 20 seconds (2 remaining * 10s)
        XCTAssertEqual(estimatedTime, 20.0)

        // WHEN: All challenges complete
        let completeState = ChallengeStackState(
            requiredChallenges: [.qr],
            completedChallenges: [.qr]
        )
        let noTime = StopAlarmAllowed.estimatedTimeUntilAllowed(
            challengeState: completeState
        )

        // THEN: Should be nil (already allowed)
        XCTAssertNil(noTime)
    }
}