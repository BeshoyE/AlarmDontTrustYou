# Sound Assets

This directory contains alarm sound files for the alarm app.

## Files Required

The app expects the following sound files:
- `default.caf` - Default alarm sound (≤30s for notifications)
- `classic.caf` - Classic alarm sound
- `chime.caf` - Chime sound
- `bell.caf` - Bell sound
- `radar.caf` - Radar sound

## Format Requirements

- **For notifications**: Files should be ≤30 seconds, loud, and in formats supported by iOS notifications (CAF, AIFF, WAV)
- **For in-app ringing**: Can be longer and will loop automatically
- Recommended format: CAF (Core Audio Format) for best iOS compatibility

## Volume Considerations

- Lock-screen notification volumes are controlled by system settings
- In-app playback volume is controlled by the app's volume slider
- Files should be normalized to prevent distortion

## Adding New Sounds

1. Add the audio file to this directory
2. Update `SoundAsset.availableSounds` in `AudioService.swift`
3. Ensure the file is added to the Xcode project bundle