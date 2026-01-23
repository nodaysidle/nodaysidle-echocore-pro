//
//  AudioRecorder.swift
//  EchoCorePro
//
//  Audio recording with real-time waveform visualization
//

import AVFoundation
import Combine
import Foundation

/// Audio recorder with waveform visualization support
@MainActor
final class AudioRecorder: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var isRecording = false
    @Published private(set) var recordingTime: TimeInterval = 0
    @Published private(set) var audioLevels: [Float] = Array(repeating: 0, count: 50)
    @Published private(set) var recordedFileURL: URL?
    
    // MARK: - Private Properties
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var recordingTimer: Timer?
    private var levelTimer: Timer?
    private let logger = OSLogManager.shared
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .default)
        try audioSession.setActive(true)
    }
    
    // MARK: - Recording Control
    
    /// Start recording audio
    func startRecording() async throws {
        // TODO: Implement actual audio recording with AVAudioRecorder
        
        logger.log("Starting audio recording", category: .lifecycle, level: .info)
        
        // Setup audio session
        try setupAudioSession()
        
        // Create temporary file for recording
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "recording_\(UUID().uuidString).m4a"
        recordingURL = tempDir.appendingPathComponent(fileName)
        
        guard let url = recordingURL else {
            throw RecordingError.fileCreationFailed
        }
        
        // TODO: Configure audio recorder settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.delegate = self
            
            guard audioRecorder?.record() == true else {
                throw RecordingError.recordingFailed
            }
            
            isRecording = true
            recordingTime = 0
            
            // Start timers for time and waveform updates
            startTimers()
            
        } catch {
            logger.log("Recording failed: \(error)", category: .lifecycle, level: .error)
            throw RecordingError.recordingFailed
        }
    }
    
    /// Stop recording and return the audio file URL
    func stopRecording() async -> URL? {
        logger.log("Stopping audio recording", category: .lifecycle, level: .info)
        
        audioRecorder?.stop()
        isRecording = false
        
        stopTimers()
        
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
        
        // Store the recorded file URL
        recordedFileURL = recordingURL
        
        return recordingURL
    }
    
    // MARK: - Timers
    
    private func startTimers() {
        // Timer for recording duration
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingTime += 0.1
            }
        }
        
        // Timer for audio level metering
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAudioLevels()
            }
        }
    }
    
    private func stopTimers() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        levelTimer?.invalidate()
        levelTimer = nil
        
        // Reset waveform
        audioLevels = Array(repeating: 0, count: 50)
    }
    
    // MARK: - Audio Level Metering
    
    private func updateAudioLevels() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        
        recorder.updateMeters()
        
        // Get average power level
        let avgPower = recorder.averagePower(forChannel: 0)
        
        // Normalize to 0.0 - 1.0 range
        // avgPower ranges from -160 dB (silent) to 0 dB (max)
        let normalized = pow(10, avgPower / 20) // Convert dB to linear scale
        
        // Shift array and add new value
        audioLevels.removeFirst()
        audioLevels.append(min(max(normalized, 0), 1))
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                logger.log("Recording finished unsuccessfully", category: .lifecycle, level: .error)
            }
        }
    }
    
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            if let error = error {
                logger.log("Recording encode error: \(error)", category: .lifecycle, level: .error)
            }
        }
    }
}

// MARK: - Recording Errors

enum RecordingError: LocalizedError {
    case permissionDenied
    case fileCreationFailed
    case recordingFailed
    case audioSessionFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission denied"
        case .fileCreationFailed:
            return "Failed to create recording file"
        case .recordingFailed:
            return "Recording failed to start"
        case .audioSessionFailed:
            return "Failed to configure audio session"
        }
    }
}
