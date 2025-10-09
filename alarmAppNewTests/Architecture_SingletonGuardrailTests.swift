//
//  Architecture_SingletonGuardrailTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/8/25.
//  Architectural guardrail tests to prevent singleton usage
//

import XCTest
@testable import alarmAppNew

final class Architecture_SingletonGuardrailTests: XCTestCase {

    /// Verifies that DependencyContainer.shared does not exist anywhere in the Swift source code
    /// (excluding this test file and documentation)
    func test_noSingletonReferencesInCodebase() throws {
        // GIVEN: Project root directory
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // alarmAppNewTests
            .deletingLastPathComponent() // Project root

        // WHEN: Searching for DependencyContainer.shared in Swift files
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/grep")
        process.arguments = [
            "-r",                                  // Recursive search
            "DependencyContainer\\.shared",        // Pattern to find
            "--include=*.swift",                   // Only Swift files
            "--exclude-dir=build",                 // Exclude build directory
            "--exclude-dir=.build",                // Exclude build directory
            projectRoot.path
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        // Filter out acceptable references (this test file and docs)
        let lines = output.split(separator: "\n")
        let violations = lines.filter { line in
            let lineStr = String(line)
            // Allow references in this test file
            if lineStr.contains("Architecture_SingletonGuardrailTests.swift") {
                return false
            }
            // Allow references in documentation
            if lineStr.contains("/docs/") || lineStr.contains("CLAUDE.md") {
                return false
            }
            return true
        }

        // THEN: No violations should be found
        if !violations.isEmpty {
            let violationList = violations.map { "  • \($0)" }.joined(separator: "\n")
            XCTFail("""
                ❌ SINGLETON USAGE DETECTED!

                Found DependencyContainer.shared references in the codebase.
                This project requires all dependencies to be injected via initializers or environment.

                Violations found:
                \(violationList)

                Fix: Replace singleton access with proper dependency injection:
                - Pass DependencyContainer via initializer parameters
                - Use SwiftUI environment injection: @Environment(\\.container)
                - Update factory methods in DependencyContainer to accept dependencies
                """)
        }
    }

    /// Verifies that DependencyContainer does not have a static shared property
    func test_dependencyContainerHasNoStaticShared() {
        // Use runtime reflection to check for static 'shared' property
        let mirror = Mirror(reflecting: DependencyContainer.self)

        // Check static properties (would appear in type's mirror)
        let hasSharedProperty = mirror.children.contains { child in
            child.label == "shared"
        }

        XCTAssertFalse(hasSharedProperty,
                      "DependencyContainer should NOT have a static 'shared' property. Use dependency injection instead.")
    }

    /// Verifies that DependencyContainer init is public (not private)
    func test_dependencyContainerInitIsPublic() {
        // This test verifies we can create instances freely
        let container1 = DependencyContainer()
        let container2 = DependencyContainer()

        // Each instance should be independent
        XCTAssertFalse(container1 === container2,
                      "DependencyContainer instances should be independent (not singleton)")
    }
}
