//
//  AppRouterTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 9/7/25.
//  Tests for AppRouter single-instance guard functionality
//

import XCTest
@testable import alarmAppNew

@MainActor
class AppRouterTests: XCTestCase {
    var router: AppRouter!
    
    override func setUp() {
        super.setUp()
        router = AppRouter()
    }
    
    // MARK: - Single Instance Guard Tests
    
    func test_showRinging_singleInstance_ignoresSubsequentRequests() {
        let firstAlarmId = UUID()
        let secondAlarmId = UUID()
        
        // When - first ringing request
        router.showRinging(for: firstAlarmId)
        
        // Then - should set route and track alarm
        XCTAssertEqual(router.route, .ringing(alarmID: firstAlarmId))
        XCTAssertTrue(router.isInDismissalFlow)
        XCTAssertEqual(router.currentDismissalAlarmId, firstAlarmId)
        
        // When - second ringing request (should be ignored)
        router.showRinging(for: secondAlarmId)
        
        // Then - route unchanged, still showing first alarm
        XCTAssertEqual(router.route, .ringing(alarmID: firstAlarmId))
        XCTAssertEqual(router.currentDismissalAlarmId, firstAlarmId)
    }
    
    func test_showDismissal_singleInstance_ignoresSubsequentRequests() {
        let firstAlarmId = UUID()
        let secondAlarmId = UUID()
        
        // When - first dismissal request
        router.showDismissal(for: firstAlarmId)
        
        // Then - should set route and track alarm
        XCTAssertEqual(router.route, .dismissal(alarmID: firstAlarmId))
        XCTAssertTrue(router.isInDismissalFlow)
        XCTAssertEqual(router.currentDismissalAlarmId, firstAlarmId)
        
        // When - second dismissal request (should be ignored)
        router.showDismissal(for: secondAlarmId)
        
        // Then - route unchanged, still showing first alarm
        XCTAssertEqual(router.route, .dismissal(alarmID: firstAlarmId))
        XCTAssertEqual(router.currentDismissalAlarmId, firstAlarmId)
    }
    
    func test_backToList_clearsActiveDismissalState() {
        let alarmId = UUID()
        
        // Given - active dismissal flow
        router.showRinging(for: alarmId)
        XCTAssertTrue(router.isInDismissalFlow)
        XCTAssertEqual(router.currentDismissalAlarmId, alarmId)
        
        // When - back to list
        router.backToList()
        
        // Then - dismissal state cleared
        XCTAssertEqual(router.route, .alarmList)
        XCTAssertFalse(router.isInDismissalFlow)
        XCTAssertNil(router.currentDismissalAlarmId)
    }
    
    func test_showRinging_afterBackToList_allowsNewDismissal() {
        let firstAlarmId = UUID()
        let secondAlarmId = UUID()
        
        // Given - first dismissal flow completed
        router.showRinging(for: firstAlarmId)
        router.backToList()
        XCTAssertFalse(router.isInDismissalFlow)
        
        // When - new ringing request
        router.showRinging(for: secondAlarmId)
        
        // Then - new dismissal flow started
        XCTAssertEqual(router.route, .ringing(alarmID: secondAlarmId))
        XCTAssertTrue(router.isInDismissalFlow)
        XCTAssertEqual(router.currentDismissalAlarmId, secondAlarmId)
    }
    
    func test_mixedRoutes_singleInstance_preventsCrossPollination() {
        let alarmId1 = UUID()
        let alarmId2 = UUID()
        
        // Given - ringing flow active
        router.showRinging(for: alarmId1)
        XCTAssertEqual(router.route, .ringing(alarmID: alarmId1))
        
        // When - try to show dismissal for different alarm
        router.showDismissal(for: alarmId2)
        
        // Then - request ignored, still in ringing flow
        XCTAssertEqual(router.route, .ringing(alarmID: alarmId1))
        XCTAssertEqual(router.currentDismissalAlarmId, alarmId1)
    }
    
    func test_initialState_allowsFirstDismissal() {
        let alarmId = UUID()
        
        // Given - initial state
        XCTAssertEqual(router.route, .alarmList)
        XCTAssertFalse(router.isInDismissalFlow)
        XCTAssertNil(router.currentDismissalAlarmId)
        
        // When - first dismissal request
        router.showRinging(for: alarmId)
        
        // Then - dismissal flow started
        XCTAssertEqual(router.route, .ringing(alarmID: alarmId))
        XCTAssertTrue(router.isInDismissalFlow)
        XCTAssertEqual(router.currentDismissalAlarmId, alarmId)
    }
}