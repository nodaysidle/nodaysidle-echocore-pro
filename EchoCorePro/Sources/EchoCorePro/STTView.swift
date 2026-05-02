//
//  STTView.swift
//  EchoCorePro
//

import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

struct STTView: View {
    @EnvironmentObject private var backend: BackendManager
    @State private var selectedAudio: URL?
    @State private var ownedRecordingURL: URL?
    @State private var recorder: AVAudioRecorder?
    @State private var recordingStartedAt: Date?
    @State private var transcript = ""
    @State private var status = "Choose an audio file to transcribe locally."
    @State private var isImporting = false
    @State private var isWorking = false
    @State private var isRecording = false

    private var canTranscribe: Bool {
        selectedAudio != nil && backend.health.ready && !isWorking && !isRecording
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Speech to Text")
                        .font(.largeTitle.weight(.semibold))
                    Text("The bundled Whisper small q4 MLX model runs locally through the Python backend.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                MetricPill(title: "Model", value: "Whisper small q4", color: .blue)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button {
                        isImporting = true
                    } label: {
                        Label(selectedAudio?.lastPathComponent ?? "Choose Audio", systemImage: "waveform")
                    }
                    .disabled(isRecording || isWorking)

                    Button {
                        isRecording ? stopRecording() : startRecording()
                    } label: {
                        Label(isRecording ? "Stop Recording" : "Record", systemImage: isRecording ? "stop.fill" : "mic.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(isRecording ? .red : nil)
                    .disabled(isWorking)

                    Button {
                        transcribe()
                    } label: {
                        Label(isWorking ? "Transcribing" : "Transcribe", systemImage: "text.quote")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canTranscribe)

                    Spacer()
                }

                HStack(spacing: 10) {
                    Circle()
                        .fill(isRecording ? .red : (selectedAudio == nil ? ECTheme.amber : ECTheme.mint))
                        .frame(width: 8, height: 8)
                    Text(status)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
            }
            .glassPanel()

            TextEditor(text: $transcript)
                .font(.title3)
                .scrollContentBackground(.hidden)
                .padding(14)
                .frame(minHeight: 380)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.10), lineWidth: 1))

            Spacer()
        }
        .padding(24)
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.audio, .mpeg4Audio, .wav],
            allowsMultipleSelection: false
        ) { result in
            if let url = try? result.get().first {
                cleanupOwnedRecording(except: url)
                selectedAudio = url
                status = "Selected \(url.lastPathComponent)"
            }
        }
        .onDisappear {
            stopRecordingIfNeeded()
            cleanupOwnedRecording()
        }
    }

    private func startRecording() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            beginRecording()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                Task { @MainActor in
                    if granted {
                        beginRecording()
                    } else {
                        status = "Microphone access was denied."
                    }
                }
            }
        case .denied, .restricted:
            status = "Enable microphone access in System Settings to record audio."
        @unknown default:
            status = "Microphone permission is unavailable."
        }
    }

    private func beginRecording() {
        cleanupOwnedRecording()
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("echocore-recording-\(UUID().uuidString)")
            .appendingPathExtension("wav")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        do {
            let recorder = try AVAudioRecorder(url: outputURL, settings: settings)
            recorder.isMeteringEnabled = true
            recorder.record()
            self.recorder = recorder
            recordingStartedAt = Date()
            selectedAudio = outputURL
            ownedRecordingURL = outputURL
            isRecording = true
            status = "Recording locally"
        } catch {
            status = error.localizedDescription
        }
    }

    private func stopRecording() {
        recorder?.stop()
        recorder = nil
        isRecording = false

        let elapsed = recordingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        recordingStartedAt = nil
        if let selectedAudio {
            status = "Recorded \(selectedAudio.lastPathComponent) (\(Int(elapsed))s)"
        } else {
            status = "Recording stopped"
        }
    }

    private func stopRecordingIfNeeded() {
        guard isRecording || recorder != nil else {
            return
        }
        stopRecording()
    }

    private func cleanupOwnedRecording(except retainedURL: URL? = nil) {
        guard let ownedRecordingURL else {
            return
        }
        if retainedURL?.standardizedFileURL == ownedRecordingURL.standardizedFileURL {
            return
        }
        try? FileManager.default.removeItem(at: ownedRecordingURL)
        self.ownedRecordingURL = nil
        if selectedAudio?.standardizedFileURL == ownedRecordingURL.standardizedFileURL {
            selectedAudio = nil
        }
    }

    private func transcribe() {
        guard let selectedAudio else { return }
        isWorking = true
        status = "Running local transcription"

        Task {
            do {
                let didStart = selectedAudio.startAccessingSecurityScopedResource()
                defer {
                    if didStart {
                        selectedAudio.stopAccessingSecurityScopedResource()
                    }
                }
                let result = try await backend.transcribe(audioURL: selectedAudio)
                await MainActor.run {
                    transcript = result.text
                    status = result.language.map { "Detected \($0)" } ?? "Complete"
                    isWorking = false
                    cleanupOwnedRecording()
                }
            } catch {
                await MainActor.run {
                    status = error.localizedDescription
                    isWorking = false
                }
            }
        }
    }
}
