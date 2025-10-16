#!/usr/bin/env python3
"""
Generate comprehensive codebase documentation markdown files.
This script creates two markdown files containing the COMPLETE codebase verbatim.
"""

import os
from pathlib import Path
from datetime import datetime

# Base path
BASE_PATH = Path("/Users/beshoy/Documents/coding_projects/alarmAppNew/alarmAppNew")

# File lists for CODEBASE_CORE.md
CORE_FILES = [
    # 1. APP ENTRY
    ("App Entry", [
        "alarmAppNewApp.swift",
    ]),

    # 2. DEPENDENCY INJECTION
    ("Dependency Injection", [
        "DI/DependencyContainer.swift",
        "DI/DependencyContainerKey.swift",
    ]),

    # 3. DOMAIN - MODELS
    ("Domain - Models", [
        "Models/Alarm.swift",
        "Models/AlarmRun.swift",
        "Models/Challenges.swift",
        "Models/MathChallenge.swift",
        "Models/Weekdays.swift",
    ]),

    # 4. DOMAIN - PROTOCOLS
    ("Domain - Protocols", [
        "Domain/Protocols/AlarmScheduling.swift",
        "Domain/Protocols/AlarmScheduling+CompatShims.swift",
        "Domain/Protocols/AlarmScheduling+Defaults.swift",
        "Domain/Protocols/AlarmSchedulingError.swift",
        "Domain/Protocols/NotificationScheduling+Alias.swift",
        "Domain/Protocols/SystemVolumeProviding.swift",
    ]),

    # 5. DOMAIN - USE CASES
    ("Domain - Use Cases", [
        "Domain/UseCases/SnoozeAlarm.swift",
        "Domain/UseCases/StopAlarmAllowed.swift",
    ]),

    # 6. DOMAIN - POLICIES
    ("Domain - Policies", [
        "Domain/Policies/AlarmPresentationPolicy.swift",
        "Domain/Policies/ChainPolicy.swift",
        "Domain/Policies/ChainSettingsProvider.swift",
    ]),

    # 7. DOMAIN - OTHER
    ("Domain - Other", [
        "Domain/Alarms/AlarmFactory.swift",
        "Domain/AudioCapability.swift",
        "Domain/AudioSessionConfig.swift",
        "Domain/AudioUXPolicy.swift",
        "Domain/Extensions/Alarm+ExternalId.swift",
        "Domain/OccurrenceKey.swift",
        "Domain/OccurrenceKeyFormatter.swift",
        "Domain/Sounds/AlarmSound.swift",
        "Domain/Sounds/SoundCatalogProviding.swift",
        "Domain/Time/NowProvider.swift",
        "Domain/Types/NotificationType.swift",
    ]),

    # 8. INFRASTRUCTURE
    ("Infrastructure", [
        "Infrastructure/ActiveAlarmPolicyProvider.swift",
        "Infrastructure/AlarmIntentBridge.swift",
        "Infrastructure/Alarms/DefaultAlarmFactory.swift",
        "Infrastructure/DeliveredNotificationsReader.swift",
        "Infrastructure/Notification+Names.swift",
        "Infrastructure/Notifications/NotificationIdentifiers.swift",
        "Infrastructure/Persistence/DismissedRegistry.swift",
        "Infrastructure/Persistence/NotificationIndex.swift",
        "Infrastructure/Services/AlarmIdMapping.swift",
        "Infrastructure/Services/AlarmKitScheduler.swift",
        "Infrastructure/Services/AlarmPresentationBuilder.swift",
        "Infrastructure/Services/AlarmSchedulerFactory.swift",
        "Infrastructure/Services/ChainedNotificationScheduler.swift",
        "Infrastructure/Services/GlobalLimitGuard.swift",
        "Infrastructure/Services/ScheduleOutcome.swift",
        "Infrastructure/Services/StorageBackedAlarmIdMapping.swift",
        "Infrastructure/Sounds/SoundCatalog.swift",
        "Infrastructure/SystemVolumeProvider.swift",
    ]),

    # 9. VIEWMODELS
    ("ViewModels", [
        "ViewModels/ActiveAlarmDetector.swift",
        "ViewModels/AlarmDetailViewModel.swift",
        "ViewModels/AlarmListViewModel.swift",
        "ViewModels/DismissalFlowViewModel.swift",
    ]),

    # 10. SERVICES
    ("Services", [
        "Services/AlarmSoundEngine.swift",
        "Services/AlarmStorage.swift",
        "Services/AudioService.swift",
        "Services/PermissionService.swift",
        "Services/PersistenceService.swift",
        "Services/QRScanningService.swift",
        "Services/RefreshCoordinator.swift",
        "Services/RefreshRequesting.swift",
        "Services/ReliabilityLogger.swift",
        "Services/ServiceProtocolExtensions.swift",
        "Services/SettingsService.swift",
    ]),

    # 11. COORDINATORS & INTENTS
    ("Coordinators & Intents", [
        "Coordinators/AppCoordinator.swift",
        "Coordinators/AppRouter.swift",
        "AppIntents/OpenForChallengeIntent.swift",
    ]),
]

# File lists for CODEBASE_UI_AND_TESTS.md
UI_FILES = [
    # 1. VIEWS
    ("Views", [
        "Views/AlarmFormView.swift",
        "Views/AlarmsListView.swift",
        "Views/ChallengeSelectionView.swift",
        "Views/ContentView.swift",
        "Views/DismissalFlowView.swift",
        "Views/PermissionBlockingView.swift",
        "Views/QRScannerView.swift",
        "Views/RingingView.swift",
        "Views/SettingsView.swift",
    ]),

    # 2. VIEW EXTENSIONS
    ("View Extensions", [
        "Extensions/View+DismissalFlow.swift",
    ]),
]


def read_file_content(file_path):
    """Read file content, return empty string if file doesn't exist."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            return f.read()
    except FileNotFoundError:
        return f"// FILE NOT FOUND: {file_path}"
    except Exception as e:
        return f"// ERROR READING FILE: {e}"


def generate_markdown(sections, title, output_file):
    """Generate a comprehensive markdown file from file sections."""

    # Start with header
    content = f"""# AlarmApp Codebase - {title}
> Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

## Table of Contents

"""

    # Generate TOC
    for idx, (section_name, files) in enumerate(sections, 1):
        content += f"{idx}. [{section_name}](#{section_name.lower().replace(' ', '-').replace('-', '-')})\n"
        for file_path in files:
            file_name = Path(file_path).name
            content += f"   - {file_name}\n"

    content += "\n---\n\n"

    # Generate content for each section
    for idx, (section_name, files) in enumerate(sections, 1):
        content += f"## {idx}. {section_name}\n\n"

        for file_path in files:
            full_path = BASE_PATH / file_path
            file_content = read_file_content(full_path)

            # Add file header with full path
            content += f"### {full_path}\n"
            content += "```swift\n"
            content += file_content
            content += "\n```\n\n"
            content += "---\n\n"

    # Write to output file
    output_path = Path("/Users/beshoy/Documents/coding_projects/alarmAppNew") / output_file
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(content)

    print(f"✅ Generated: {output_path}")
    print(f"   Size: {len(content):,} bytes")
    print(f"   Files: {sum(len(files) for _, files in sections)}")


def main():
    """Main entry point."""
    print("🚀 Generating comprehensive codebase documentation...\n")

    # Generate CODEBASE_CORE.md
    generate_markdown(CORE_FILES, "CORE", "CODEBASE_CORE.md")
    print()

    # Generate CODEBASE_UI_AND_TESTS.md
    generate_markdown(UI_FILES, "UI AND VIEWS", "CODEBASE_UI_AND_TESTS.md")
    print()

    print("✨ Documentation generation complete!")


if __name__ == "__main__":
    main()
