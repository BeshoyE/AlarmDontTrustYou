# AlarmDontTrustYou - Codebase Export Manifest

**Export Date:** November 4, 2025
**Export File:** `CODEBASE_EXPORT.md`
**File Size:** 758 KB
**Total Files:** 125
**Total Lines of Code:** 21,747

## Overview

This manifest documents the complete codebase export for the AlarmDontTrustYou iOS application. The export contains all source code, tests, documentation, and configuration files organized into a single markdown file for easy distribution and reference.

## File Breakdown

### Documentation Files (11 files)

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Architecture & Engineering Guide - Master specification |
| `changelog.md` | Project change history and version notes |
| `docs/00-foundations.md` | Design foundations (colors, typography, spacing) |
| `docs/Domain/use-cases.md` | Pure Swift domain layer use cases |
| `docs/mvp1.md` | MVP 1 (QR-only) specification |
| `docs/v1-core.md` | V1 (Core Reliability) specification |
| `docs/v2-accountability-bedtime.md` | V2 (Accountability & Bedtime) specification |
| `docs/v3-monetization-advanced.md` | V3 (Monetization & Advanced) specification |
| `docs/claude-guardrails.md` | Development guardrails and constraints |
| `docs/MVP1_MANUAL_SMOKE_TEST_CHECKLIST.md` | Manual testing checklist |
| `alarmAppNew/Resources/Sounds/README.md` | Sound assets documentation |

### Configuration Files (2 files)

| File | Purpose |
|------|---------|
| `alarmAppNew/Info.plist` | iOS app configuration |
| `alarmAppNew.xcodeproj/project.pbxproj` | Xcode project configuration |

### Source Code Files (79 files)

#### Coordinators (2 files)
- `AppCoordinator.swift` - App navigation coordination
- `AppRouter.swift` - Router implementation

#### App Intent (1 file)
- `OpenForChallengeIntent.swift` - App intent handler

#### Domain Layer (11 files)
- `Alarms/AlarmFactory.swift`
- `AudioCapability.swift`
- `AudioSessionConfig.swift`
- `AudioUXPolicy.swift`
- `Extensions/Alarm+ExternalId.swift`
- `OccurrenceKey.swift`
- `OccurrenceKeyFormatter.swift`
- `Policies/AlarmPresentationPolicy.swift`
- `Policies/ChainPolicy.swift`
- `Policies/ChainSettingsProvider.swift`
- `Sounds/AlarmSound.swift`

#### Domain Protocols (7 files)
- `Protocols/AlarmAudioEngineError.swift`
- `Protocols/AlarmScheduling.swift`
- `Protocols/AlarmScheduling+CompatShims.swift`
- `Protocols/AlarmScheduling+Defaults.swift`
- `Protocols/AlarmSchedulingError.swift`
- `Protocols/IdleTimerControlling.swift`
- `Protocols/PersistenceStore.swift`
- `Protocols/SystemVolumeProviding.swift`
- `Protocols/AlarmRunStoreError.swift`

#### Dependency Injection (2 files)
- `DI/DependencyContainer.swift` - Main DI container
- `DI/DependencyContainerKey.swift` - DI environment keys

#### Domain Time (1 file)
- `Domain/Time/NowProvider.swift` - Time abstraction

#### Domain Use Cases (2 files)
- `Domain/UseCases/SnoozeAlarm.swift`
- `Domain/UseCases/StopAlarmAllowed.swift`

#### Domain Sounds (1 file)
- `Domain/Sounds/SoundCatalogProviding.swift`

#### Domain Types (1 file)
- `Domain/Types/NotificationType.swift`

#### Extensions (1 file)
- `Extensions/View+DismissalFlow.swift`

#### Infrastructure Services (12 files)
- `Infrastructure/AlarmIntentBridge.swift`
- `Infrastructure/ActiveAlarmPolicyProvider.swift`
- `Infrastructure/DeliveredNotificationsReader.swift`
- `Infrastructure/Notification+Names.swift`
- `Infrastructure/ShareProvider.swift`
- `Infrastructure/SystemVolumeProvider.swift`
- `Infrastructure/UIApplicationIdleTimerController.swift`
- `Services/AlarmSoundEngine.swift`
- `Services/QRScanningService.swift`
- `Services/SettingsService.swift`
- `Services/RefreshCoordinator.swift`
- `Services/RefreshRequesting.swift`

#### Infrastructure Scheduler (5 files)
- `Infrastructure/Services/AlarmKitScheduler.swift`
- `Infrastructure/Services/AlarmSchedulerFactory.swift`
- `Infrastructure/Services/ChainedNotificationScheduler.swift`
- `Infrastructure/Services/AlarmPresentationBuilder.swift`
- `Infrastructure/Services/GlobalLimitGuard.swift`
- `Infrastructure/Services/ScheduleOutcome.swift`

#### Infrastructure Notifications (2 files)
- `Infrastructure/Notifications/NotificationIdentifiers.swift`

#### Infrastructure Persistence (3 files)
- `Infrastructure/Persistence/AlarmRunStore.swift`
- `Infrastructure/Persistence/DismissedRegistry.swift`
- `Infrastructure/Persistence/NotificationIndex.swift`

#### Infrastructure Alarms (1 file)
- `Infrastructure/Alarms/DefaultAlarmFactory.swift`

#### Infrastructure Sounds (1 file)
- `Infrastructure/Sounds/SoundCatalog.swift`

#### Models (4 files)
- `Models/Alarm.swift`
- `Models/AlarmRun.swift`
- `Models/Challenges.swift`
- `Models/MathChallenge.swift`
- `Models/Weekdays.swift`

#### Services (4 files)
- `Services/PermissionService.swift`
- `Services/PersistenceService.swift`
- `Services/ReliabilityLogger.swift`
- `Services/ServiceProtocolExtensions.swift`

#### ViewModels (6 files)
- `ViewModels/ActiveAlarmDetector.swift`
- `ViewModels/AlarmDetailViewModel.swift`
- `ViewModels/AlarmListViewModel.swift`
- `ViewModels/DismissalFlowViewModel.swift`
- `ViewModels/SettingsViewModel.swift`

#### Views (6 files)
- `Views/AlarmFormView.swift`
- `Views/AlarmsListView.swift`
- `Views/ChallengeSelectionView.swift`
- `Views/ContentView.swift`
- `Views/DismissalFlowView.swift`
- `Views/PermissionBlockingView.swift`
- `Views/QRScannerView.swift`
- `Views/RingingView.swift`
- `Views/SettingsView.swift`

#### App Entry Point (1 file)
- `alarmAppNewApp.swift` - App main entry point

### Test Files (33 files)

#### Integration Tests (5 files)
- `AlarmKitIntegrationTests.swift`
- `ChainedSchedulingIntegrationTests.swift`
- `Integration_TestAlarmSchedulingTests.swift`
- `NotificationIntegrationTests.swift`

#### E2E Tests (2 files)
- `E2E_AlarmDismissalFlowTests.swift`
- `E2E_DismissalFlowSoundTests.swift`

#### Unit Tests - Domain (6 files)
- `Unit/Domain/AlarmStopSemanticsTests.swift`
- `Unit/Domain/ChainPolicyTests.swift`
- `Unit/Domain/ChainSettingsProviderTests.swift`
- `Unit/Domain/ScheduleMappingDSTTests.swift`
- `Unit/Domain/SnoozePolicyTests.swift`
- `Unit/Domain/Sounds/SoundCatalogTests.swift`

#### Unit Tests - Infrastructure (9 files)
- `Unit/Infrastructure/AlarmKitSchedulerTests.swift`
- `Unit/Infrastructure/AlarmSchedulerFactoryTests.swift`
- `Unit/Infrastructure/AlarmSoundEngineTests.swift`
- `Unit/Infrastructure/ChainedNotificationSchedulerTests.swift`
- `Unit/Infrastructure/GlobalLimitGuardTests.swift`
- `Unit/Infrastructure/IntentBridgeFreshnessTests.swift`
- `Unit/Infrastructure/IntentBridgeNoSingletonTests.swift`
- `Unit/Infrastructure/NotificationIdentifierContractTests.swift`
- `Unit/Infrastructure/NotificationIndexTests.swift`
- `Unit/Infrastructure/SettingsServiceTests.swift`
- `Unit/Infrastructure/WillPresentSuppressionTests.swift`

#### Unit Tests - Models (1 file)
- `Unit/Alarms/AlarmFactoryTests.swift`

#### Architecture Tests (2 files)
- `Architecture_SingletonGuardrailTests.swift`
- `Unit/ArchitectureGuardrailTests.swift`

#### ViewModel Tests (2 files)
- `AlarmListViewModelTests.swift`
- `DismissalFlowViewModelTests.swift`

#### Router Tests (1 file)
- `AppRouterTests.swift`

#### Other Tests (2 files)
- `NotificationServiceTests.swift`
- `Unit_VolumeWarningTests.swift`

#### Test Support (2 files)
- `TestMocks.swift`
- `alarmAppNewTests.swift`

## Key Features Documented

### Architecture
- Layered architecture with clear separation of concerns
- Domain → Infrastructure → Presentation layers
- Protocol-first dependency injection
- Actor-based concurrency for shared state

### Core Functionality
- **Alarm Scheduling:** AlarmKit/UserNotifications integration
- **Challenges:** QR scanning, steps counting, math problems
- **Dismissal Flow:** Sequential challenge completion
- **Audio Enhancement:** Continuous playback with notification suppression
- **Persistence:** Actor-based thread-safe storage

### Quality Assurance
- Comprehensive unit tests for domain logic
- Integration tests for service coordination
- End-to-end tests for user flows
- Architecture guardrail tests

### Documentation
- Complete product specification
- Technical architecture guide
- Development guardrails and constraints
- Manual testing checklist
- Use case definitions

## How to Use This Export

1. **For Development:** Reference the architecture guide (CLAUDE.md) for structure and patterns
2. **For Testing:** Use the MVP1_MANUAL_SMOKE_TEST_CHECKLIST.md for validation
3. **For Onboarding:** Start with 00-foundations.md and then CLAUDE.md
4. **For Reference:** Use the codebase export as a searchable reference of all source
5. **For CI/CD:** Configuration files provide project setup details

## Technical Stack

- **Language:** Swift 5.9+
- **Framework:** SwiftUI
- **Minimum iOS:** iOS 17+
- **Architecture Pattern:** Layered with DI
- **Concurrency Model:** Swift async/await with actors
- **Testing:** XCTest and Swift Testing

## Important Notes

- All persistence services are implemented as Swift actors for thread safety
- Main thread is protected; no blocking I/O on main thread
- Error handling uses typed domain errors (no silent catches)
- Initialization is pure (no side effects in constructors)
- All observable events are structured logged

## Contact & Attribution

Project: AlarmDontTrustYou
Export Generated: November 4, 2025
Total Export Size: 758 KB

---

**End of Manifest**
