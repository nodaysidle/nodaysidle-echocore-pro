//
//  VoiceCloningView.swift
//  EchoCorePro
//
//  Voice cloning interface using Qwen3-TTS via MLX
//  Record reference audio -> Clone -> Synthesize with your voice
//

import AVFoundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Constants

private enum ViewConstants {
    static let wavHeaderMinSize = 44
    static let waveformBars = 50
    static let minRecordingDuration: TimeInterval = 3.0
    static let maxRecordingDuration: TimeInterval = 120.0
}

// MARK: - Voice Cloning View

struct VoiceCloningView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var recorder = AudioRecorder()
    @StateObject private var viewModel = VoiceCloningViewModel()

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

    // Model parameters
    @State private var temperature: Float = 0.9
    @State private var topK: Int = 50
    @State private var topP: Float = 1.0
    @State private var repetitionPenalty: Float = 1.05
    @State private var maxTokens: Int = 8192
    @State private var refText: String = ""
    @State private var showAdvancedSettings = false

    // Rename dialog
    @State private var showRenameDialog = false
    @State private var renameText = ""

    // Cloning result
    @State private var clonedSpeakerId: String?
    @State private var audioPlayerInstance: AVAudioPlayer?

    // Audio player state
    @State private var isPlaying = false
    @State private var playbackProgress: Double = 0
    @State private var audioDuration: Double = 0
    @State private var waveformLevels: [Float] = Array(repeating: 0.3, count: 40)

    // Design system color aliases
    private let brandPurple  = DS.Fuchsia.primary
    private let brandViolet  = DS.Fuchsia.secondary
    private let brandMagenta = DS.Fuchsia.glow
    private let brandIndigo  = DS.Fuchsia.primary

    // Qwen3-TTS supports 10 languages
    private let languages = [
        ("en", "English"),
        ("zh", "Chinese"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("fr", "French"),
        ("de", "German"),
        ("es", "Spanish"),
        ("it", "Italian"),
        ("pt", "Portuguese"),
        ("ru", "Russian"),
    ]

    var body: some View {
        HSplitView {
            // Left: Recording & Cloning
            VStack(spacing: 0) {
                headerBar
                ScrollView {
                    VStack(spacing: 24) {
                        serverStatusCard
                        recordingSection
                        fileUploadSection
                        cloneButtonSection
                        cloningProgressSection
                        successSection
                    }
                    .padding()
                }
            }
            .frame(minWidth: 400)

            // Right: Synthesis
            VStack(spacing: 0) {
                HStack {
                    Text("Voice Synthesis")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(DS.Text.primary)
                    Spacer()
                }
                .padding()
                .background(DS.Surface.dark)

                ScrollView {
                    VStack(spacing: 24) {
                        speakerSelector
                        synthesisInput
                        synthesisSettings
                        synthesizeButton
                        audioPlayerSection
                    }
                    .padding()
                }
            }
            .frame(minWidth: 350)
        }
        .background(
            StudioBackground(accentColor: DS.Fuchsia.primary, glowOffsetX: -200, glowOffsetY: -100)
        )
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .sheet(isPresented: $showRenameDialog) {
            renameSheet
        }
        .task {
            await viewModel.checkServerHealth()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            VoiceCloneIcon(color: brandViolet)
                .frame(width: 24, height: 24)
            Text("Voice Cloning")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Qwen3-TTS")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(DS.Fuchsia.primary.opacity(0.2))
                .foregroundStyle(DS.Fuchsia.secondary)
                .clipShape(Capsule())

            Spacer()

            Button {
                Task { await viewModel.checkServerHealth() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(viewModel.isServerHealthy ? .green : .red)
            }
            .buttonStyle(.plain)
            .help("Refresh server status")
        }
        .padding()
        .background(DS.Surface.dark)
    }

    // MARK: - Server Status

    private var serverStatusCard: some View {
        let serverManager = coordinator.serviceRegistry.pythonServerManager
        let vuLevel: Int = viewModel.isServerHealthy ? 5 : (serverManager.isRunning ? 2 : 0)
        return HStack(spacing: 12) {
            VUMeterView(level: vuLevel)

            VStack(alignment: .leading, spacing: 2) {
                Text("Qwen3-TTS 1.7B")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(DS.Text.primary)
                Text(viewModel.isServerHealthy ? "Ready · 10 languages" : serverManager.statusMessage)
                    .font(.caption)
                    .foregroundStyle(DS.Text.secondary)
            }

            Spacer()

            if !viewModel.isServerHealthy {
                ProgressView()
                    .controlSize(.small)
                    .tint(DS.Fuchsia.secondary)
            }
        }
        .padding(12)
        .studioCard(10)
    }

    // MARK: - Recording Section

    private var recordingSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Record Reference Audio")
                    .font(.headline)
                    .foregroundStyle(DS.Text.primary)
                Text("6+ seconds recommended")
                    .font(.caption)
                    .foregroundStyle(DS.Text.tertiary)
                Spacer()
            }

            waveformView
                .frame(height: 80)
                .padding(.horizontal, 20)
                .background(RoundedRectangle(cornerRadius: 10).fill(DS.Surface.dark))

            Text(formatTime(recorder.recordingTime))
                .font(.system(size: 32, weight: .ultraLight, design: .monospaced))
                .foregroundStyle(recorder.isRecording ? DS.Fuchsia.secondary : DS.Text.tertiary)

            recordButton
        }
        .padding()
        .studioCard(16)
    }

    private var waveformView: some View {
        HStack(spacing: 2) {
            ForEach(0..<recorder.audioLevels.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        recorder.isRecording
                            ? LinearGradient(colors: [.red, .orange], startPoint: .bottom, endPoint: .top)
                            : LinearGradient(colors: [DS.Fuchsia.primary.opacity(0.3), DS.Fuchsia.secondary.opacity(0.5)], startPoint: .bottom, endPoint: .top)
                    )
                    .frame(width: 3, height: max(3, CGFloat(recorder.audioLevels[index]) * 60))
                    .animation(.spring(response: 0.08, dampingFraction: 0.6), value: recorder.audioLevels[index])
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(recorder.isRecording ? 1 : 0.5)
    }

    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.0

    private var recordButton: some View {
        ZStack {
            // Pulsing outer ring when recording
            Circle()
                .stroke(Color.red.opacity(0.5), lineWidth: 3)
                .frame(width: 82, height: 82)
                .scaleEffect(pulseScale)
                .opacity(pulseOpacity)

            Button {
                Task { await toggleRecording() }
            } label: {
                ZStack {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: recorder.isRecording ? [.red, .orange] : [DS.Fuchsia.primary, DS.Fuchsia.secondary],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 70, height: 70)
                    Circle()
                        .fill(
                            recorder.isRecording
                                ? AnyShapeStyle(LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                                : AnyShapeStyle(LinearGradient(colors: [DS.Fuchsia.primary, DS.Fuchsia.secondary], startPoint: .topLeading, endPoint: .bottomTrailing))
                        )
                        .frame(width: 52, height: 52)
                    Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isCloning)
            .onChange(of: recorder.isRecording) { _, isRec in
                if isRec {
                    pulseScale = 1.0; pulseOpacity = 0.6
                    withAnimation(.easeOut(duration: 1.0).repeatForever(autoreverses: false)) {
                        pulseScale = 1.45; pulseOpacity = 0.0
                    }
                } else {
                    pulseScale = 1.0; pulseOpacity = 0.0
                }
            }
        }
    }

    // MARK: - File Upload

    private var fileUploadSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Or Upload Audio File")
                    .font(.subheadline)
                    .foregroundStyle(DS.Text.primary)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if let audioURL = selectedAudioURL {
                selectedFileCard(url: audioURL)
            } else {
                uploadButton
            }
        }
        .padding()
        .studioCard(16)
    }

    private func selectedFileCard(url: URL) -> some View {
        HStack {
            Image(systemName: "waveform")
                .font(.title2)
                .foregroundStyle(DS.Fuchsia.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(url.lastPathComponent)
                    .font(.subheadline)
                    .foregroundStyle(DS.Text.primary)
                    .lineLimit(1)

                if let duration = selectedAudioDuration {
                    Text(String(format: "Duration: %.1f seconds", duration))
                        .font(.caption)
                        .foregroundStyle(DS.Text.secondary)
                }
            }

            Spacer()

            Button { clearSelectedFile() } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(DS.Text.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10).fill(DS.Surface.dark))
    }

    private var uploadButton: some View {
        Button { selectAudioFile() } label: {
            VStack(spacing: 8) {
                Image(systemName: "arrow.up.doc.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(DS.Fuchsia.secondary)

                Text("Select WAV File")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(DS.Text.primary)

                Text("6-60 seconds recommended")
                    .font(.caption)
                    .foregroundStyle(DS.Text.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(DS.Fuchsia.primary.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [8]))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Clone Button

    @ViewBuilder
    private var cloneButtonSection: some View {
        if (recorder.recordedFileURL != nil || selectedAudioURL != nil)
            && !viewModel.isCloning
            && clonedSpeakerId == nil {
            GlowButton(
                label: "Clone My Voice",
                icon: "person.2.fill",
                accentColor: DS.Fuchsia.primary,
                accentSecondary: DS.Fuchsia.secondary
            ) {
                Task { await cloneVoice() }
            }
        }
    }

    // MARK: - Cloning Progress

    @ViewBuilder
    private var cloningProgressSection: some View {
        if viewModel.isCloning {
            HStack {
                ProgressView()
                    .controlSize(.small)
                    .tint(DS.Fuchsia.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Cloning Voice...")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(DS.Text.primary)
                    Text("Extracting voice characteristics")
                        .font(.caption)
                        .foregroundStyle(DS.Text.secondary)
                }

                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(DS.Fuchsia.primary.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(DS.Fuchsia.primary.opacity(0.3), lineWidth: 0.5))
            )
        }
    }

    // MARK: - Success Card

    @ViewBuilder
    private var successSection: some View {
        if let speakerId = clonedSpeakerId, !viewModel.isCloning {
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
                            await viewModel.deleteSpeaker(speakerId)
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
                    .fill(DS.Semantic.success.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(DS.Semantic.success.opacity(0.3), lineWidth: 0.5))
            )
        }
    }

    // MARK: - Speaker Selector

    private var speakerSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cloned Voice")
                .font(.headline)
                .foregroundStyle(DS.Text.primary)

            if viewModel.speakers.isEmpty {
                Text("No voices cloned yet. Record and clone your voice first.")
                    .font(.caption)
                    .foregroundStyle(DS.Text.tertiary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 10).fill(DS.Surface.dark))
            } else {
                HStack {
                    Picker("Speaker", selection: $selectedSpeakerId) {
                        Text("Select a voice...").tag(nil as String?)
                        ForEach(viewModel.speakers, id: \.id) { speaker in
                            Text("\(speaker.id) (\(String(format: "%.1fs", speaker.duration)))").tag(speaker.id as String?)
                        }
                    }
                    .pickerStyle(.menu)

                    if selectedSpeakerId != nil {
                        Button {
                            renameText = selectedSpeakerId ?? ""
                            showRenameDialog = true
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Rename voice")

                        Button {
                            if let id = selectedSpeakerId {
                                Task {
                                    await viewModel.deleteSpeaker(id)
                                    selectedSpeakerId = nil
                                }
                            }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Delete voice")
                    }
                }
            }
        }
        .padding()
        .studioCard()
    }

    // MARK: - Synthesis Input

    private var synthesisInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Text to Speak")
                    .font(.headline)
                    .foregroundStyle(DS.Text.primary)
                Spacer()
                Text("Auto-chunked for long text")
                    .font(.caption)
                    .foregroundStyle(DS.Text.tertiary)
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $synthesizeText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(DS.Text.primary)
                    .frame(minHeight: 200)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(DS.Surface.dark))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.Border.subtle, lineWidth: 0.5))

                if synthesizeText.isEmpty {
                    Text("Enter the text you want to speak in your cloned voice...")
                        .font(.body)
                        .foregroundStyle(DS.Text.disabled)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding()
        .studioCard()
    }

    // MARK: - Synthesis Settings

    private var synthesisSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.headline)
                .foregroundStyle(DS.Text.primary)

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

            HStack {
                Text("Speed")
                    .frame(width: 80, alignment: .leading)
                Slider(value: $speechSpeed, in: 0.5...2.0)
                    .tint(brandPurple)
                Text("\(String(format: "%.1f", speechSpeed))x")
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }

            Divider().opacity(0.3)

            // Collapsible model parameters
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showAdvancedSettings.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.caption)
                        .foregroundStyle(brandViolet)
                    Text("Model Parameters")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showAdvancedSettings ? 90 : 0))
                }
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            if showAdvancedSettings {
                VStack(spacing: 10) {
                    parameterRow(
                        label: "Temperature",
                        value: $temperature,
                        range: 0.0...2.0,
                        format: "%.2f",
                        help: "Randomness. Higher = more natural variation"
                    )

                    parameterRow(
                        label: "Top-K",
                        intValue: $topK,
                        range: 1...200,
                        help: "Only consider top K token choices"
                    )

                    parameterRow(
                        label: "Top-P",
                        value: $topP,
                        range: 0.01...1.0,
                        format: "%.2f",
                        help: "Nucleus sampling cutoff"
                    )

                    parameterRow(
                        label: "Rep. Penalty",
                        value: $repetitionPenalty,
                        range: 1.0...2.0,
                        format: "%.2f",
                        help: "Penalize repeated audio patterns"
                    )

                    parameterRow(
                        label: "Max Tokens",
                        intValue: $maxTokens,
                        range: 100...4096,
                        help: "Maximum generation length"
                    )

                    // Ref text field
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Ref. Transcript")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("optional")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        TextField("Transcript of your reference audio...", text: $refText)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                            .help("Providing a transcript of your reference audio improves cloning accuracy")
                    }

                    // Reset button
                    HStack {
                        Spacer()
                        Button("Reset to Defaults") {
                            temperature = 0.9
                            topK = 50
                            topP = 1.0
                            repetitionPenalty = 1.05
                            maxTokens = 4096
                            refText = ""
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .studioCard()
    }

    // MARK: - Parameter Row Helpers

    private func parameterRow(
        label: String,
        value: Binding<Float>,
        range: ClosedRange<Float>,
        format: String,
        help: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 90, alignment: .leading)
                Slider(value: value, in: range)
                    .tint(brandViolet)
                Text(String(format: format, value.wrappedValue))
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
            .help(help)
        }
    }

    private func parameterRow(
        label: String,
        intValue: Binding<Int>,
        range: ClosedRange<Int>,
        help: String
    ) -> some View {
        let floatBinding = Binding<Float>(
            get: { Float(intValue.wrappedValue) },
            set: { intValue.wrappedValue = Int($0) }
        )
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 90, alignment: .leading)
                Slider(value: floatBinding, in: Float(range.lowerBound)...Float(range.upperBound))
                    .tint(brandViolet)
                Text("\(intValue.wrappedValue)")
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
            .help(help)
        }
    }

    // MARK: - Synthesize Button

    private var synthesizeButton: some View {
        GlowButton(
            label: "Generate Speech",
            icon: "speaker.wave.3.fill",
            accentColor: DS.Fuchsia.primary,
            accentSecondary: DS.Fuchsia.secondary,
            isLoading: viewModel.isSynthesizing,
            isDisabled: selectedSpeakerId == nil || synthesizeText.isEmpty || viewModel.isSynthesizing
        ) {
            Task { await synthesize() }
        }
    }

    // MARK: - Audio Player

    @ViewBuilder
    private var audioPlayerSection: some View {
        if let audioURL = synthesizedAudioURL {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "waveform")
                        .foregroundStyle(DS.Fuchsia.secondary)
                    Text("Generated Speech")
                        .font(.headline)
                        .foregroundStyle(DS.Text.primary)
                    Spacer()

                    if audioDuration > 0 {
                        Text(formatDuration(audioDuration))
                            .font(.caption)
                            .foregroundStyle(DS.Text.tertiary)
                            .fontDesign(.monospaced)
                    }
                }

                audioWaveformView
                    .frame(height: 50)

                HStack(spacing: 16) {
                    Button {
                        togglePlayback(url: audioURL)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [DS.Fuchsia.primary, DS.Fuchsia.secondary], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 44, height: 44)
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white)
                                .offset(x: isPlaying ? 0 : 2)
                        }
                    }
                    .buttonStyle(.plain)

                    Slider(value: $playbackProgress, in: 0...1) { editing in
                        if !editing, let player = audioPlayerInstance {
                            player.currentTime = player.duration * playbackProgress
                        }
                    }
                    .tint(DS.Fuchsia.primary)

                    Button { saveAudio(url: audioURL) } label: {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title2)
                            .foregroundStyle(DS.Fuchsia.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Save audio file")

                    Button {
                        Task { await synthesize() }
                    } label: {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.title2)
                            .foregroundStyle(DS.Text.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Regenerate")
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(DS.Surface.dark))
            }
            .padding()
            .studioCard()
            .onAppear {
                generateWaveformLevels()
                loadAudioDuration(url: audioURL)
            }
        }
    }

    // Lightweight waveform visualization
    private var audioWaveformView: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<waveformLevels.count, id: \.self) { index in
                    let progress = Double(index) / Double(waveformLevels.count)
                    let isPlayed = progress <= playbackProgress

                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            isPlayed
                                ? LinearGradient(colors: [DS.Fuchsia.primary, DS.Fuchsia.secondary], startPoint: .bottom, endPoint: .top)
                                : LinearGradient(colors: [DS.Border.subtle, DS.Surface.light], startPoint: .bottom, endPoint: .top)
                        )
                        .frame(
                            width: max(2, (geometry.size.width - CGFloat(waveformLevels.count - 1) * 2) / CGFloat(waveformLevels.count)),
                            height: max(4, CGFloat(waveformLevels[index]) * geometry.size.height)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func generateWaveformLevels() {
        // Generate pseudo-random waveform levels that look natural
        waveformLevels = (0..<40).map { i in
            let base: Float = 0.3
            let variation = Float.random(in: 0.2...0.9)
            // Create peaks in the middle, taper at edges
            let position = Float(i) / 40.0
            let envelope = sin(position * .pi) * 0.4 + 0.6
            return min(1.0, max(0.15, (base + variation) * envelope))
        }
    }

    private func loadAudioDuration(url: URL) {
        if let audioFile = try? AVAudioFile(forReading: url) {
            audioDuration = Double(audioFile.length) / audioFile.fileFormat.sampleRate
        }
    }

    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func togglePlayback(url: URL) {
        if isPlaying {
            audioPlayerInstance?.pause()
            isPlaying = false
        } else {
            playAudio(url: url)
        }
    }

    // MARK: - Rename Sheet

    private var renameSheet: some View {
        VStack(spacing: 16) {
            Text("Rename Voice")
                .font(.headline)

            TextField("New name", text: $renameText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)

            HStack {
                Button("Cancel") {
                    showRenameDialog = false
                }
                .buttonStyle(.bordered)

                Button("Rename") {
                    if let oldId = selectedSpeakerId, !renameText.isEmpty {
                        Task {
                            if let newName = await viewModel.renameSpeaker(oldId, to: renameText) {
                                selectedSpeakerId = newName
                            }
                            showRenameDialog = false
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(renameText.isEmpty)
            }
        }
        .padding(24)
    }

    // MARK: - Actions

    private func toggleRecording() async {
        if recorder.isRecording {
            _ = await recorder.stopRecording()
        } else {
            do {
                try await recorder.startRecording()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func cloneVoice() async {
        let audioURL: URL
        if let uploadedURL = selectedAudioURL {
            audioURL = uploadedURL
        } else if let recordedURL = recorder.recordedFileURL {
            audioURL = recordedURL
        } else {
            errorMessage = "No recording or file available"
            return
        }

        guard viewModel.isModelLoaded else {
            errorMessage = "Qwen3-TTS model not loaded. Please wait for the server to start."
            return
        }

        let speakerId = UUID().uuidString.prefix(8).lowercased()

        viewModel.isCloning = true
        let response = await viewModel.cloneVoice(from: audioURL, speakerId: String(speakerId))

        if response.success {
            clonedSpeakerId = String(speakerId)
            clearSelectedFile()
            await viewModel.refreshSpeakers()
        } else {
            errorMessage = response.message
        }

        viewModel.isCloning = false
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

        viewModel.isSynthesizing = true
        let startTime = CFAbsoluteTimeGetCurrent()

        let audioData: Data
        do {
            audioData = try await viewModel.synthesize(
                text: synthesizeText,
                speakerId: speakerId,
                language: selectedLanguage,
                speed: speechSpeed,
                temperature: temperature,
                topK: topK,
                topP: topP,
                repetitionPenalty: repetitionPenalty,
                maxTokens: maxTokens,
                refText: refText
            )
        } catch {
            errorMessage = error.localizedDescription
            viewModel.isSynthesizing = false
            return
        }

        let processingTimeMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

        guard audioData.count > ViewConstants.wavHeaderMinSize else {
            errorMessage = "No audio data received from server"
            viewModel.isSynthesizing = false
            return
        }

        do {
            let tempDir = FileManager.default.temporaryDirectory
            let filename = "synthesized_\(UUID().uuidString).wav"
            let audioURL = tempDir.appendingPathComponent(filename)
            try audioData.write(to: audioURL)

            // Get audio duration
            var audioDuration: Double = 0
            if let audioFile = try? AVAudioFile(forReading: audioURL) {
                audioDuration = Double(audioFile.length) / audioFile.fileFormat.sampleRate
            }

            // Record to history
            HistoryService.shared.setContext(modelContext)
            HistoryService.shared.recordSynthesis(
                modelName: "Qwen3-TTS",
                inputText: synthesizeText,
                outputDurationSeconds: audioDuration,
                processingTimeMs: processingTimeMs
            )

            synthesizedAudioURL = audioURL
            playAudio(url: audioURL)
        } catch {
            errorMessage = error.localizedDescription
        }

        viewModel.isSynthesizing = false
    }

    private func playAudio(url: URL) {
        do {
            audioPlayerInstance?.stop()
            audioPlayerInstance = try AVAudioPlayer(contentsOf: url)
            audioPlayerInstance?.play()
            isPlaying = true

            // Update progress periodically
            Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
                guard let player = audioPlayerInstance else {
                    timer.invalidate()
                    return
                }

                if player.isPlaying {
                    playbackProgress = player.currentTime / player.duration
                } else {
                    isPlaying = false
                    if playbackProgress >= 0.99 {
                        playbackProgress = 0
                    }
                    timer.invalidate()
                }
            }
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

    private func selectAudioFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.wav, .audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a WAV audio file (6+ seconds recommended)"

        if panel.runModal() == .OK, let url = panel.url {
            selectedAudioURL = url

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
    @Published private(set) var speakers: [VoiceCloningService.SpeakerInfo] = []
    @Published var isCloning = false
    @Published var isSynthesizing = false

    private let service = VoiceCloningService()

    func checkServerHealth() async {
        isServerHealthy = await service.checkHealth()

        if isServerHealthy {
            isModelLoaded = await service.isModelLoaded()
            await refreshSpeakers()
        } else {
            await startServerIfNeeded()
        }
    }

    private func startServerIfNeeded() async {
        // The PythonServerManager handles server startup via ServiceRegistry
        // Poll for health as the server starts in the background

        OSLogManager.shared.log("Waiting for TTS server to start...", category: .inference, level: .info)

        // Poll for health for up to 90 seconds (Qwen3-TTS + Piper take time to load)
        for attempt in 0..<90 {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if await service.checkHealth() {
                isServerHealthy = true
                isModelLoaded = await service.isModelLoaded()
                await refreshSpeakers()
                OSLogManager.shared.log("TTS server ready after \(attempt + 1)s", category: .inference, level: .info)
                return
            }
        }

        OSLogManager.shared.log("TTS server did not start in time", category: .inference, level: .error)
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

    func renameSpeaker(_ id: String, to newName: String) async -> String? {
        do {
            let result = try await service.renameSpeaker(id, to: newName)
            await refreshSpeakers()
            return result
        } catch {
            return nil
        }
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

    func synthesize(
        text: String,
        speakerId: String,
        language: String,
        speed: Float,
        temperature: Float,
        topK: Int,
        topP: Float,
        repetitionPenalty: Float,
        maxTokens: Int,
        refText: String
    ) async throws -> Data {
        try await service.synthesize(
            text: text,
            speakerId: speakerId,
            language: language,
            speed: speed,
            temperature: temperature,
            topK: topK,
            topP: topP,
            repetitionPenalty: repetitionPenalty,
            maxTokens: maxTokens,
            refText: refText
        )
    }
}

// MARK: - UTType Extension

extension UTType {
    static let wav = UTType(filenameExtension: "wav")!
}

#Preview {
    VoiceCloningView()
        .frame(width: 900, height: 600)
}
