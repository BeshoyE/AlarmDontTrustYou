//
//  AudioService.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/8/25.
//  Audio service for alarm sound playback and management
//

import AVFoundation
import Foundation

// MARK: - Sound Asset

struct SoundAsset: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let displayName: String
    let fileName: String

    static let availableSounds: [SoundAsset] = [
        SoundAsset(name: "default", displayName: "Default", fileName: "ringtone1.caf"),
        SoundAsset(name: "classic", displayName: "Classic", fileName: "classic.caf"),
        SoundAsset(name: "chime", displayName: "Chime", fileName: "chime.caf"),
        SoundAsset(name: "bell", displayName: "Bell", fileName: "bell.caf"),
        SoundAsset(name: "radar", displayName: "Radar", fileName: "radar.caf")
    ]
}

// MARK: - Audio Service Protocol

protocol AudioServiceProtocol {
    func listAvailableSounds() -> [SoundAsset]
    func preview(soundName: String?, volume: Double) async
    func startRinging(soundName: String?, volume: Double, loop: Bool) async
    func stop()
    func stopAndDeactivateSession()
    func isPlaying() -> Bool
    func activatePlaybackSession() throws
    func deactivateSession() throws
}

// MARK: - Audio Service Implementation


class AudioService: NSObject, AudioServiceProtocol {
    private var audioPlayer: AVAudioPlayer?
    private var isCurrentlyPlaying = false
    private var isSessionActive = false

    override init() {
        super.init()
        setupInterruptionHandling()
    }

    deinit {
        stopAndDeactivateSession()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Audio Session Management

    func activatePlaybackSession() throws {
        guard !isSessionActive else {
            print("🔊 AudioService: Session already active, skipping activation")
            return
        }

        let audioSession = AVAudioSession.sharedInstance()
        // Use .playback without .defaultToSpeaker (not compatible)
        // The system will route to speaker by default for alarm sounds
        try audioSession.setCategory(.playback, mode: .default, options: [])
        try audioSession.setActive(true)
        isSessionActive = true

        print("🔊 AudioService: Setting category: playback, mode: default")
        print("🔊 AudioService: Audio session activated: true")
    }

    func deactivateSession() throws {
        guard isSessionActive else { return }

        try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isSessionActive = false

        print("AudioService: Deactivated audio session")
    }
    
    private func setupInterruptionHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            print("AudioService: Audio interruption began - pausing playback")
            audioPlayer?.pause()
            
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) && isCurrentlyPlaying {
                    print("AudioService: Audio interruption ended - resuming playback")
                    audioPlayer?.play()
                }
            }
            
        @unknown default:
            break
        }
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable:
            print("AudioService: Route change detected (\(reason)) - continuing playback")
            // Continue playing on route changes like AirPods connect/disconnect
            if isCurrentlyPlaying && audioPlayer?.isPlaying == false {
                audioPlayer?.play()
            }
            
        default:
            break
        }
    }
    
    // MARK: - Protocol Implementation
    
    func listAvailableSounds() -> [SoundAsset] {
        return SoundAsset.availableSounds
    }
    
    func preview(soundName: String?, volume: Double) async {
        await playSound(soundName: soundName, volume: volume, loop: false, isPreview: true)
    }
    
    func startRinging(soundName: String?, volume: Double, loop: Bool = true) async {
        do {
            try activatePlaybackSession()
            isCurrentlyPlaying = true
            await playSound(soundName: soundName, volume: volume, loop: loop, isPreview: false)
        } catch {
            print("AudioService: Failed to activate session for ringing: \(error)")
        }
    }

    nonisolated func stop() {
        isCurrentlyPlaying = false
        audioPlayer?.stop()
        audioPlayer = nil
    }

    func stopAndDeactivateSession() {
        stop()
        do {
            try deactivateSession()
        } catch {
            print("AudioService: Failed to deactivate audio session: \(error)")
        }
    }
    
    func isPlaying() -> Bool {
        return audioPlayer?.isPlaying ?? false
    }
    
    // MARK: - Private Helpers
    
    private func playSound(soundName: String?, volume: Double, loop: Bool, isPreview: Bool) async {
        // Stop any existing playback
        if !isPreview {
            audioPlayer?.stop()
        }
        
        // Get sound file URL
        guard let soundURL = getSoundURL(for: soundName) else {
            print("AudioService: Could not find sound file for '\(soundName ?? "nil")' - using default")
            guard let defaultURL = getSoundURL(for: "default") else {
                print("AudioService: Could not find default sound file")
                return
            }
            await playAudioFile(url: defaultURL, volume: volume, loop: loop)
            return
        }
        
        await playAudioFile(url: soundURL, volume: volume, loop: loop)
    }
    
    private func playAudioFile(url: URL, volume: Double, loop: Bool) async {
        do {
            // Ensure audio session is active for playback
            if !isSessionActive {
                try activatePlaybackSession()
            }

            // Create and configure audio player
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            let clampedVolume = Float(max(0.0, min(1.0, volume)))
            audioPlayer?.volume = clampedVolume
            audioPlayer?.numberOfLoops = loop ? -1 : 0  // -1 for infinite loop

            // Play the sound
            let didStart = audioPlayer?.play() ?? false

            if didStart {
                print("🔊 AudioService: Audio player started (rate: \(audioPlayer?.rate ?? 0.0), volume: \(clampedVolume))")
            } else {
                print("❌ AudioService: Audio player failed to start")
            }

        } catch {
            print("❌ AudioService: Failed to play sound at \(url): \(error)")
        }
    }
    
    private func getSoundURL(for soundName: String?) -> URL? {
        let name = soundName ?? "default"
        
        // Find the sound asset
        guard let soundAsset = SoundAsset.availableSounds.first(where: { $0.name == name }) else {
            return nil
        }
        
        // Get bundle URL for the sound file
        let fileName = soundAsset.fileName
        let nameWithoutExtension = String(fileName.prefix(upTo: fileName.lastIndex(of: ".") ?? fileName.endIndex))
        let fileExtension = String(fileName.suffix(from: fileName.index(after: fileName.lastIndex(of: ".") ?? fileName.startIndex)))
        
        return Bundle.main.url(forResource: nameWithoutExtension, withExtension: fileExtension)
    }
}
