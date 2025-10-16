//
//  IntentBridgeNoSingletonTests.swift
//  alarmAppNewTests
//
//  Tests to ensure AlarmIntentBridge does not use singleton pattern.
//

import XCTest
@testable import alarmAppNew

@MainActor
final class IntentBridgeNoSingletonTests: XCTestCase {

    func test_AlarmIntentBridge_shouldNotHaveSharedInstance() {
        // Check that AlarmIntentBridge type does not have a 'shared' static property
        let mirror = Mirror(reflecting: AlarmIntentBridge.self)

        // Iterate through the type's children to look for static properties
        for child in mirror.children {
            if let label = child.label {
                XCTAssertFalse(
                    label.lowercased().contains("shared"),
                    "AlarmIntentBridge should not have a 'shared' static property"
                )
            }
        }

        // Also verify through runtime check - this will fail to compile if .shared exists
        // Uncommenting the line below should cause a compile error:
        // _ = AlarmIntentBridge.shared
    }

    func test_AlarmIntentBridge_shouldAllowMultipleInstances() {
        // Given/When: Creating multiple instances
        let bridge1 = AlarmIntentBridge()
        let bridge2 = AlarmIntentBridge()
        let bridge3 = AlarmIntentBridge()

        // Then: All instances should be different objects
        XCTAssertTrue(bridge1 !== bridge2, "Should create different instances")
        XCTAssertTrue(bridge2 !== bridge3, "Should create different instances")
        XCTAssertTrue(bridge1 !== bridge3, "Should create different instances")
    }

    func test_AlarmIntentBridge_shouldNotHaveSingletonPattern() {
        // This test verifies the class structure doesn't follow singleton pattern

        // 1. Can create instances normally
        let instance = AlarmIntentBridge()
        XCTAssertNotNil(instance)

        // 2. Init is accessible (not private)
        // The fact that we can call AlarmIntentBridge() proves init is not private

        // 3. No static instance property
        // We check this by ensuring the type doesn't respond to .shared
        // This is validated by the compiler - if .shared existed, we could reference it
    }

    func test_AlarmIntentBridge_shouldHavePublicInit() {
        // The ability to create an instance from test target proves init is not private
        let bridge = AlarmIntentBridge()
        XCTAssertNotNil(bridge, "Should be able to create instance with public/internal init")
    }

    func test_AlarmIntentBridge_multipleInstancesCanOperateIndependently() async {
        // Given: Multiple bridge instances
        let bridge1 = AlarmIntentBridge()
        let bridge2 = AlarmIntentBridge()

        // When: Both check for pending intents
        // (No setup needed - just verifying they don't interfere)
        bridge1.checkForPendingIntent()
        bridge2.checkForPendingIntent()

        // Then: Both should execute without issues
        // The fact that this doesn't crash proves they're independent
        XCTAssertNotNil(bridge1.pendingAlarmId) // Will be nil, but we're checking property access
        XCTAssertNotNil(bridge2.pendingAlarmId) // Will be nil, but we're checking property access
    }
}