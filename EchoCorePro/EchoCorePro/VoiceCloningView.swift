//
//  VoiceCloningView.swift
//  EchoCorePro
//
//  Voice cloning interface: record reference audio → clone → synthesize
//

import AVFoundation
import SwiftData
import SwiftUI

struct VoiceCloningView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var recorder = AudioRecorder()
    @StateObject private var cloningViewModel = VoiceCloningViewModel()

    @State private var synthesizeText = ""
    @State private var synthesizedAudioURL: URL?
    @State private var errorMessage: String?
    @State private var selectedSpeakerId: String?

    // File upload state
    @State private var selectedAudioURL: URL?
    @State private var selectedAudioDuration: TimeInterval?

    // Synthesis settings
    @State private var selectedLanguage = "en"
    @State private var speechSpeed: Float = 1.0

    // Qwen3-TTS supports 10 languages
    private let languages = [
        ("en", "English"),
        ("it", "Italian"),
        ("de", "German"),
        ("fr", "French"),
        ("es", "Spanish"),
        ("pt", "Portuguese"),
        ("ru", "Russian"),
        ("zh", "Chinese"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
    ]

    var body: some View {
        HSplitView {
            // Left: Recording & Cloning
            VStack(spacing: 0) {
                headerBar

                ScrollView {
                    VStack(spacing: 24) {
                        // Server status
                        serverStatusCard

                        // Recording section
                        recordingSection

                        // File upload section (alternative to recording)
                        fileUploadSection

                        // Clone button
                        if (recorder.recordedFileURL != nil || selectedAudioURL != nil)
                            && !cloningViewModel.isCloning
                            && clonedSpeakerId == nil
                        {
                            cloneButton
                        }

                        // Cloning progress
                        if cloningViewModel.isCloning {
                            cloningProgress
                        }

                        // Success message
                        if let speakerId = clonedSpeakerId, !cloningViewModel.isCloning {
                            successCard(speakerId: speakerId)
                        }
                    }
                    .padding()
                }
            }
            .frame(minWidth: 400)

            // Right: Synthesis
            VStack(spacing: 0) {
                Text("Voice Synthesis")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial)

                ScrollView {
                    VStack(spacing: 24) {
                        // Speaker selection
                        speakerSelector

                        // Text input
                        synthesisInput

                        // Settings
                        synthesisSettings

                        // Synthesize button
                        synthesizeButton

                        // Audio player
                        if let audioURL = synthesizedAudioURL {
                            audioPlayer(url: audioURL)
                        }
                    }
                    .padding()
                }
            }
            .frame(minWidth: 350)
        }
        .background(
            LinearGradient(
                colors: [Color(white: 0.05), Color(white: 0.08), Color(white: 0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .alert(
            "Error",
            isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .task {
            await cloningViewModel.checkServerHealth()
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            Label("Voice Cloning", systemImage: "person.wave.2.fill")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Button {
                Task { await cloningViewModel.checkServerHealth() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(cloningViewModel.isServerHealthy ? .green : .red)
            }
            .buttonStyle(.plain)
            .help("Refresh server status")
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - Server Status Card

    private var serverStatusCard: some View {
        HStack {
            Circle()
                .fill(cloningViewModel.isServerHealthy ? Color.green : Color.red)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text("Qwen3-TTS")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(
                    cloningViewModel.isServerHealthy
                        ? "Ready • 10 languages" : "Starting server..."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if !cloningViewModel.isServerHealthy {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }

    private func modelDisplayName(for modelName: String) -> String {
        return "Qwen3-TTS (10 languages)"
    }

    // MARK: - Recording Section

    private var recordingSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Record Reference Audio")
                    .font(.headline)
                Text("6+ seconds recommended")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            // Waveform
            waveformView
                .frame(height: 80)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(white: 0.1))
                )

            // Time display
            Text(formatTime(recorder.recordingTime))
                .font(.system(size: 32, weight: .ultraLight, design: .monospaced))
                .foregroundStyle(recorder.isRecording ? .primary : .secondary)

            // Record button
            Button {
                Task { await toggleRecording() }
            } label: {
                ZStack {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: recorder.isRecording ? [.red, .orange] : [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 70, height: 70)

                    Circle()
                        .fill(
                            recorder.isRecording
                                ? AnyShapeStyle(Color.red)
                                : AnyShapeStyle(
                                    LinearGradient(
                                        colors: [.blue, .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                        )
                        .frame(width: 50, height: 50)

                    Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .disabled(cloningViewModel.isCloning)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    private var waveformView: some View {
        HStack(spacing: 2) {
            ForEach(0..<recorder.audioLevels.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        LinearGradient(
                            colors: recorder.isRecording
                                ? [.red, .orange, .yellow]
                                : [.gray.opacity(0.3), .gray.opacity(0.5)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3, height: max(3, CGFloat(recorder.audioLevels[index]) * 60))
                    .animation(
                        .spring(response: 0.1, dampingFraction: 0.6),
                        value: recorder.audioLevels[index])
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(recorder.isRecording ? 1 : 0.5)
    }

    // MARK: - File Upload Section

    private var fileUploadSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Or Upload Audio File")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if let audioURL = selectedAudioURL {
                // File selected - show info
                HStack {
                    Image(systemName: "waveform")
                        .font(.title2)
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(audioURL.lastPathComponent)
                            .font(.subheadline)
                            .lineLimit(1)

                        if let duration = selectedAudioDuration {
                            Text(String(format: "Duration: %.1f seconds", duration))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button {
                        clearSelectedFile()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(white: 0.1))
                )
            } else {
                // No file selected - show upload button
                Button {
                    selectAudioFile()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.up.doc.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.blue)

                        Text("Select WAV File")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("6-60 seconds recommended")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                Color.blue.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [8])
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Clone Button

    private var cloneButton: some View {
        Button {
            Task {
                await cloneVoice()
            }
        } label: {
            HStack {
                Image(systemName: "person.2.fill")
                Text("Clone My Voice")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [.blue, .cyan],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Cloning Progress

    private var cloningProgress: some View {
        HStack {
            ProgressView()
                .controlSize(.small)

            VStack(alignment: .leading, spacing: 2) {
                Text("Cloning Voice...")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Extracting voice characteristics from reference audio")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.blue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Success Card

    private func successCard(speakerId: String) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Voice Cloned Successfully!")
                        .font(.headline)
                    Text("Speaker ID: \(speakerId)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(speakerId, forType: .string)
                } label: {
                    Label("Copy ID", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    Task {
                        await cloningViewModel.deleteSpeaker(speakerId)
                        clonedSpeakerId = nil
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button {
                    selectedSpeakerId = speakerId
                } label: {
                    Label("Use This Voice", systemImage: "arrow.right")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.green.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Speaker Selector

    private var speakerSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cloned Voice")
                .font(.headline)

            if cloningViewModel.speakers.isEmpty {
                Text("No voices cloned yet. Record and clone your voice first.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(white: 0.1))
                    )
            } else {
                Picker("Speaker", selection: $selectedSpeakerId) {
                    Text("Select a voice...").tag(nil as String?)
                    ForEach(cloningViewModel.speakers, id: \.self) { speaker in
                        Text(speaker).tag(speaker as String?)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Synthesis Input

    private var synthesisInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Text to Speak")
                .font(.headline)

            TextEditor(text: $synthesizeText)
                .font(.body)
                .frame(minHeight: 200)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(white: 0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Synthesis Settings (Simplified for Qwen3)

    private var synthesisSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.headline)

            // Language
            HStack {
                Text("Language")
                    .frame(width: 80, alignment: .leading)
                Picker("", selection: $selectedLanguage) {
                    ForEach(languages, id: \.0) { code, name in
                        Text(name).tag(code)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
            }

            // Speed
            HStack {
                Text("Speed")
                    .frame(width: 80, alignment: .leading)

                Slider(value: $speechSpeed, in: 0.5...2.0)
                    .tint(.blue)

                Text("\(String(format: "%.1f", speechSpeed))x")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 40)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }

    private func settingSlider(
        title: String, value: Binding<Float>, range: ClosedRange<Float>, step: Float, format: String
    ) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .frame(width: 80, alignment: .leading)
            Slider(value: value, in: range, step: step)
            Text(String(format: format, value.wrappedValue))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 40)
        }
    }

    // MARK: - Synthesize Button

    private var synthesizeButton: some View {
        Button {
            Task {
                await synthesize()
            }
        } label: {
            HStack {
                if cloningViewModel.isSynthesizing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "speaker.wave.3.fill")
                }
                Text(cloningViewModel.isSynthesizing ? "Generating..." : "Generate Speech")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                selectedSpeakerId != nil && !synthesizeText.isEmpty
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [Color(white: 0.35), Color(white: 0.25)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    : AnyShapeStyle(Color.gray.opacity(0.5))
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(
            selectedSpeakerId == nil || synthesizeText.isEmpty || cloningViewModel.isSynthesizing)
    }

    // MARK: - Audio Player

    private func audioPlayer(url: URL) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(.green)
                Text("Generated Speech")
                    .font(.headline)
                Spacer()
            }

            // Simple audio player controls
            HStack(spacing: 16) {
                Button {
                    // Play audio using AVPlayer
                    playAudio(url: url)
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.title)
                }
                .buttonStyle(.plain)

                Button {
                    saveAudio(url: url)
                } label: {
                    Label("Save", systemImage: "arrow.down.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(white: 0.15))
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - State

    @State private var clonedSpeakerId: String?
    @State private var audioPlayerInstance: AVAudioPlayer?

    // MARK: - Actions

    private func toggleRecording() async {
        if recorder.isRecording {
            _ = await recorder.stopRecording()
            // Keep recording ready for cloning
        } else {
            do {
                try await recorder.startRecording()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func cloneVoice() async {
        // Support both uploaded file and microphone recording
        let audioURL: URL
        if let uploadedURL = selectedAudioURL {
            audioURL = uploadedURL
        } else if let recordedURL = recorder.recordedFileURL {
            audioURL = recordedURL
        } else {
            errorMessage = "No recording or file available"
            return
        }

        guard cloningViewModel.isModelLoaded else {
            errorMessage = "Qwen3-TTS model not loaded. Please wait for the server to start."
            return
        }

        let speakerId = UUID().uuidString.prefix(8).lowercased()

        cloningViewModel.isCloning = true
        let response = await cloningViewModel.cloneVoice(
            from: audioURL, speakerId: String(speakerId))

        if response.success {
            clonedSpeakerId = String(speakerId)
            // Clear the selected file after successful clone
            clearSelectedFile()
            await cloningViewModel.refreshSpeakers()
        } else {
            errorMessage = response.message
        }

        cloningViewModel.isCloning = false
    }

    private func synthesize() async {
        guard let speakerId = selectedSpeakerId else {
            errorMessage = "Please select a cloned voice first"
            return
        }

        guard !synthesizeText.isEmpty else {
            errorMessage = "Please enter text to synthesize"
            return
        }

        do {
            cloningViewModel.isSynthesizing = true
            let startTime = CFAbsoluteTimeGetCurrent()

            let audioData = await cloningViewModel.synthesize(
                text: synthesizeText,
                speakerId: speakerId,
                language: selectedLanguage,
                speed: speechSpeed
            )

            let processingTimeMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

            // Save to temp file
            let tempDir = FileManager.default.temporaryDirectory
            let filename = "synthesized_\(UUID().uuidString).wav"
            let audioURL = tempDir.appendingPathComponent(filename)

            try audioData.write(to: audioURL)

            // Get audio duration for history
            let audioDuration: Double
            if let audioFile = try? AVAudioFile(forReading: audioURL) {
                audioDuration = Double(audioFile.length) / audioFile.fileFormat.sampleRate
            } else {
                audioDuration = 0
            }

            // Record to history
            HistoryService.shared.setContext(modelContext)
            HistoryService.shared.recordSynthesis(
                modelName: cloningViewModel.modelDisplayName,
                inputText: synthesizeText,
                outputDurationSeconds: audioDuration,
                processingTimeMs: processingTimeMs
            )

            synthesizedAudioURL = audioURL

            // Auto-play
            playAudio(url: audioURL)
        } catch {
            errorMessage = error.localizedDescription
        }

        cloningViewModel.isSynthesizing = false
    }

    private func playAudio(url: URL) {
        do {
            audioPlayerInstance?.stop()
            audioPlayerInstance = try AVAudioPlayer(contentsOf: url)
            audioPlayerInstance?.play()
        } catch {
            errorMessage = "Could not play audio: \(error.localizedDescription)"
        }
    }

    private func saveAudio(url: URL) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.wav]
        savePanel.nameFieldStringValue = "cloned_speech.wav"

        savePanel.begin { response in
            if response == .OK, let destURL = savePanel.url {
                try? FileManager.default.copyItem(at: url, to: destURL)
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - File Upload Actions

    private func selectAudioFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.wav, .audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a WAV audio file (6+ seconds recommended)"

        if panel.runModal() == .OK, let url = panel.url {
            selectedAudioURL = url

            // Get audio duration
            let asset = AVAsset(url: url)
            Task {
                do {
                    let duration = try await asset.load(.duration)
                    selectedAudioDuration = duration.seconds
                } catch {
                    errorMessage = "Could not read audio file duration"
                }
            }
        }
    }

    private func clearSelectedFile() {
        selectedAudioURL = nil
        selectedAudioDuration = nil
    }
}

// MARK: - ViewModel

@MainActor
class VoiceCloningViewModel: ObservableObject {
    @Published private(set) var isServerHealthy = false
    @Published private(set) var isModelLoaded = false
    @Published private(set) var speakers: [String] = []
    @Published var isCloning = false
    @Published var isSynthesizing = false

    // Model selection (qwen3 only)
    @Published var activeModel: String = "qwen3"

    @Published var temperature: Float = 0.7
    @Published var topP: Float = 0.8
    @Published var repetitionPenalty: Float = 2.0
    @Published var minP: Float = 0.05
    @Published var cfgWeight: Float = 0.0
    @Published var exaggeration: Float = 0.0
    @Published var chunkSize: Int = 200
    @Published var minChunkSeconds: Float = 2.0
    @Published var chunkRetries: Int = 0

    private let service = VoiceCloningService()

    func checkServerHealth() async {
        isServerHealthy = await service.checkHealth()

        if isServerHealthy {
            isModelLoaded = await service.isModelLoaded()
            await refreshSpeakers()
        } else {
            // Try to start the server if not running
            await startServerIfNeeded()
        }
    }

    var modelDisplayName: String {
        return "Qwen3-TTS"
    }

    private func startServerIfNeeded() async {
        // Try multiple locations for the server script
        let possiblePaths = [
            // Development: Scripts folder in project
            "/Volumes/omarchyuser/projekti/nodaysidle-echocore-pro/EchoCorePro/Scripts",
            // Built app: inside app bundle
            Bundle.main.resourcePath.map { "\($0)/Scripts" },
            // Fallback: relative to Documents
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
                .deletingLastPathComponent()
                .appendingPathComponent("EchoCorePro/Scripts")
                .path,
        ].compactMap { $0 }

        // Find the script directory
        var scriptsDir: String?
        for path in possiblePaths {
            let pythonScript = (path as NSString).appendingPathComponent("openvoice_server.py")
            if FileManager.default.fileExists(atPath: pythonScript) {
                scriptsDir = path
                break
            }
        }

        guard let scriptsDir = scriptsDir else {
            OSLogManager.shared.log(
                "Could not find Scripts directory", category: .inference, level: .error)
            return
        }

        // Try to start the server
        do {
            let process = Process()
            let pythonPath = (scriptsDir as NSString).appendingPathComponent("venv/bin/python")
            let serverScript = (scriptsDir as NSString).appendingPathComponent(
                "openvoice_server.py")

            if FileManager.default.fileExists(atPath: pythonPath) {
                process.executableURL = URL(fileURLWithPath: pythonPath)
                process.arguments = [serverScript]
            } else {
                // Fallback: try system python3
                process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
                process.arguments = [serverScript]
            }

            // Set working directory (important for imports)
            process.currentDirectoryURL = URL(fileURLWithPath: scriptsDir)
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            try process.run()
            OSLogManager.shared.log(
                "Started voice server from: \(scriptsDir)", category: .inference, level: .info)

            // Poll health endpoint
            for _ in 0..<15 {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                if await service.checkHealth() {
                    isServerHealthy = true
                    isModelLoaded = await service.isModelLoaded()
                    await refreshSpeakers()
                    return
                }
            }
        } catch {
            OSLogManager.shared.log(
                "Failed to start voice server: \(error)", category: .inference, level: .error)
        }
    }

    func refreshSpeakers() async {
        do {
            speakers = try await service.listSpeakers()
        } catch {
            speakers = []
        }
    }

    func deleteSpeaker(_ id: String) async {
        try? await service.deleteSpeaker(id)
        await refreshSpeakers()
    }

    func cloneVoice(from url: URL, speakerId: String) async -> VoiceCloningService.CloneResponse {
        do {
            return try await service.cloneVoice(from: url, speakerId: speakerId)
        } catch {
            return VoiceCloningService.CloneResponse(
                speakerId: speakerId,
                durationSeconds: 0,
                success: false,
                message: error.localizedDescription
            )
        }
    }

    func synthesize(text: String, speakerId: String, language: String, speed: Float) async -> Data {
        do {
            return try await service.synthesize(
                text: text,
                speakerId: speakerId,
                language: language,
                speed: speed,
                temperature: temperature,
                topP: topP,
                repetitionPenalty: repetitionPenalty,
                minP: minP,
                cfgWeight: cfgWeight,
                exaggeration: exaggeration,
                chunkSize: chunkSize,
                minChunkSeconds: minChunkSeconds,
                chunkRetries: chunkRetries
            )
        } catch {
            return Data()
        }
    }
}

// MARK: - File Type UTType

extension UTType {
    static let wav = UTType(filenameExtension: "wav")!
}

#Preview {
    VoiceCloningView()
        .frame(width: 900, height: 600)
}
