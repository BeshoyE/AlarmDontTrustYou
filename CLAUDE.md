# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an iOS alarm app built with SwiftUI implementing a QR-based dismissal system. The app requires users to scan a pre-registered QR code to dismiss alarms, preventing easy snoozing/dismissal.

## Build Commands

This is a standard Xcode project. Build and run using:
- **Build**: Open `alarmAppNew.xcodeproj` in Xcode and use Cmd+B
- **Run**: Use Cmd+R in Xcode or select a simulator/device
- **Tests**: Currently no test target exists - this is a known gap

## Architecture Overview

### Core Data Flow
The app uses a coordinator pattern with two main coordinators:
- `AppRouter`: Manages app-level navigation (alarm list ↔ dismissal flow)
- `AppCoordinator`: Handles dismissal coordination (legacy, being replaced by AppRouter)

### Key Architecture Patterns

**MVVM with Dependency Injection**: Views are backed by ViewModels, with `DependencyContainer` providing service injection.

**Protocol-Based Services**: All services implement protocols for testability and loose coupling.

**Permission-First Design**: Hard-blocking UI when required permissions are denied, with Settings deep links.

### Data Models

**Core Models**:
- `Alarm`: Main alarm entity with time, repeat schedule, challenges, and QR payload
- `Challenges`: Enum defining dismissal challenge types (QR, Steps, Math)
- `Weekdays`: Enum for repeat day selection
- `NotificationPermissionDetails`: Rich permission status with alerts/sound/badge details

**Missing MVP1 Model**: `AlarmRun` for tracking alarm execution outcomes is not yet implemented.

### Service Layer

**PermissionService**: Handles notification and camera permission requests with detailed status
- Provides rich notification permission details (authorized but muted, etc.)
- Includes Settings deep link functionality

**NotificationService**: Implements `NotificationScheduling` protocol
- Permission-aware scheduling with proper error handling
- App lifecycle notification re-registration via `refreshAll()`
- Throws `NotificationError` when permissions denied

**PersistenceService**: Implements `AlarmStorage` protocol using UserDefaults JSON encoding.

### View Architecture

**Main Views**:
- `AlarmsListView`: Primary alarm management interface with permission warnings
- `AlarmFormView`: Create/edit alarm with challenge configuration  
- `DismissalFlowView`: Currently stub - intended for full-screen alarm ringing
- `QRScannerView`: QR code scanning with camera permission handling

**Permission UI**:
- `NotificationPermissionBlockingView`: Full-screen blocking for notification permissions
- `CameraPermissionBlockingView`: Full-screen blocking for camera permissions  
- `NotificationPermissionInlineWarning`: Inline warnings in alarm list

**ViewModels**:
- `AlarmListViewModel`: Manages alarm collection with permission integration
- `AlarmDetailViewModel`: Handles individual alarm editing state
- `DismissalFlowViewModel`: Orchestrates dismissal challenge flow (incomplete)

### External Dependencies

- **CodeScanner** (2.5.2): Third-party QR code scanning library

## Permission Handling

### Hard-Blocking Design (MVP1 Requirement)
- **Notifications**: Blocks alarm scheduling if denied; shows Settings deep link
- **Camera**: Blocks QR dismissal until granted; explains rationale with Settings link

### Permission Flow
1. Check permissions before critical operations
2. Show rationale and request if not determined
3. Hard-block with Settings deep link if denied
4. Provide inline warnings for "authorized but muted" states

### Info.plist Entries Required
- `NSCameraUsageDescription`: QR scanning rationale
- `NSUserNotificationUsageDescription`: Alarm notification rationale

## MVP1 Implementation Status

This codebase has comprehensive permission handling implemented. Key remaining MVP1 gaps:
- Full dismissal flow implementation (currently stub)
- AlarmRun model for tracking alarm outcomes  
- Reliability logging system
- Test coverage

## Navigation Flow

1. App starts with `AlarmsListView`
2. Permission warnings shown inline if issues detected
3. Notification fires → `NotificationService` posts `alarmDidFire`
4. App should navigate to `DismissalFlowView` for QR scanning
5. Camera permission checked before QR scanner presentation
6. Successful scan should dismiss alarm and log outcome

## App Lifecycle Management

- **App Launch**: `DependencyContainer` initializes all services
- **Scene Active**: Automatic notification re-registration via `refreshAll()`
- **Permission Changes**: Real-time permission monitoring and UI updates

## File Organization

- `/Models`: Core data structures (`Alarm`, `Challenges`, `Weekdays`)
- `/Services`: Business logic layer with protocol-based design
- `/ViewModels`: MVVM view models with dependency injection
- `/Views`: SwiftUI views with permission-aware flows
- `/Coordinators`: Navigation coordination
- `/Extensions`: SwiftUI extensions
- `/DI`: Dependency injection container
- `/docs`: Architecture documentation and requirements

## Important Implementation Notes

- Uses protocol-based architecture with DependencyContainer injection
- Permission-first design blocks operations until proper access granted
- All async operations use proper Task/async-await patterns
- Services are not singletons - injected via DI container
- Rich permission status provides detailed feedback (authorized but muted, etc.)
- App lifecycle automatically re-registers notifications on active state