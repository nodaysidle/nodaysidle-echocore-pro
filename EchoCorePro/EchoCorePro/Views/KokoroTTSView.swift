//
//  KokoroTTSView.swift
//  EchoCorePro
//
//  High-quality natural TTS with Kokoro
//

import SwiftUI
import AVFoundation

struct KokoroTTSView: View {
    // MARK: - State
    @State private var selectedLanguage = "en_US"
    @State private var selectedVoice = "af_sarah"
    @State private var text = ""
    @State private var speed: Double = 1.0
    @State private var isGenerating = false
    @State private var statusMessage = "Ready"
    @State private var isModelReady = false

    // Audio playback
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var generatedAudioData: Data?
    private let service = KokoroTTSService()

    private let brandCyan   = DS.Cyan.secondary
    private let brandPurple = DS.Fuchsia.primary

    // Available languages
    private let languages = [
        ("en_US", "English (US)"),
        ("en_GB", "English (UK)"),
        ("it_IT", "Italian"),
    ]

    // Available voices organized by language - fetched dynamically from server
    @State private var voicesByLanguage: [String: [(id: String, name: String, gender: String)]] = [:]
    @State private var isLoadingVoices = true

    // Current language's voices
    private var voices: [(id: String, name: String, gender: String)] {
        voicesByLanguage[selectedLanguage] ?? []
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left panel - Voice selection
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack {
                        KokoroIcon(color: DS.Cyan.secondary)
                            .frame(width: 32, height: 32)
                        Text("Kokoro TTS")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(DS.Text.primary)

                        Text("Natural")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(DS.Cyan.primary.opacity(0.2))
                            .foregroundStyle(DS.Cyan.secondary)
                            .clipShape(Capsule())

                        Spacer()

                        Button {
                            checkModelStatus()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(DS.Text.tertiary)
                        }
                        .buttonStyle(.plain)
                    }

                    // Status indicator (VU meter style)
                    HStack(spacing: 10) {
                        VUMeterView(level: isModelReady ? 5 : 2)
                        Text(statusMessage)
                            .font(.subheadline)
                            .foregroundStyle(DS.Text.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(DS.Surface.dark)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Language selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Language")
                            .font(.headline)
                            .foregroundStyle(DS.Text.primary)

                        Picker("Language", selection: $selectedLanguage) {
                            ForEach(languages, id: \.0) { lang in
                                Text(lang.1).tag(lang.0)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(DS.Surface.dark)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onChange(of: selectedLanguage) { _, newLang in
                            if let firstVoice = voicesByLanguage[newLang]?.first {
                                selectedVoice = firstVoice.id
                            } else {
                                selectedVoice = ""
                            }
                        }
                    }

                    // Voice grid
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Voice")
                                .font(.headline)
                                .foregroundStyle(DS.Text.primary)
                            Spacer()
                            Text("\(voices.count) available")
                                .font(.caption)
                                .foregroundStyle(DS.Text.tertiary)
                        }

                        if isLoadingVoices {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(DS.Cyan.secondary)
                                Text("Loading voices from server...")
                                    .font(.subheadline)
                                    .foregroundStyle(DS.Text.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(DS.Surface.dark)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else if voices.isEmpty {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(DS.Text.tertiary)
                                Text("No voices available for this language")
                                    .font(.subheadline)
                                    .foregroundStyle(DS.Text.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(DS.Surface.dark)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                            ], spacing: 12) {
                                ForEach(voices, id: \.id) { voice in
                                    VoiceCard(
                                        name: voice.name,
                                        gender: voice.gender,
                                        isSelected: selectedVoice == voice.id,
                                        accentColor: brandCyan
                                    ) {
                                        selectedVoice = voice.id
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(DS.Surface.mid)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(DS.Border.subtle, lineWidth: 0.5))

                    Spacer()
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity)
            .background(DS.BG.secondary)

            // Right panel - Text input and generate
            VStack(alignment: .leading, spacing: 20) {
                Text("Voice Synthesis")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(DS.Text.primary)

                // Text input
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Text to Speak")
                            .font(.headline)
                            .foregroundStyle(DS.Text.primary)
                        Spacer()
                        Text("Unlimited characters")
                            .font(.caption)
                            .foregroundStyle(DS.Text.tertiary)
                    }

                    TextEditor(text: $text)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(DS.Text.primary)
                        .padding(12)
                        .frame(minHeight: 150)
                        .background(DS.Surface.dark)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DS.Border.subtle, lineWidth: 0.5))

                    // Quick text buttons
                    HStack {
                        Text("Try:")
                            .font(.caption)
                            .foregroundStyle(DS.Text.tertiary)

                        Button("Hello!") {
                            text = "Hello! Welcome to Kokoro, the natural text to speech engine."
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("Long text") {
                            text = "The quick brown fox jumps over the lazy dog. This sentence contains every letter of the alphabet. Kokoro produces natural, human-like speech with proper intonation and emotion, making it perfect for any text-to-speech application."
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                Spacer()

                // Settings
                VStack(alignment: .leading, spacing: 16) {
                    Text("Settings")
                        .font(.headline)
                        .foregroundStyle(DS.Text.primary)

                    // Speed slider
                    HStack {
                        Text("Speed")
                            .foregroundStyle(DS.Text.secondary)
                        Spacer()
                        Slider(value: $speed, in: 0.5...2.0, step: 0.1)
                            .frame(maxWidth: 300)
                            .tint(DS.Cyan.primary)
                        Text(String(format: "%.1fx", speed))
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 50)
                    }
                }

                // Generate button
                GlowButton(
                    label: "Generate Speech",
                    icon: "speaker.wave.2.fill",
                    accentColor: DS.Cyan.primary,
                    accentSecondary: DS.Cyan.secondary,
                    isLoading: isGenerating,
                    isDisabled: text.isEmpty || isGenerating || !isModelReady || voices.isEmpty || selectedVoice.isEmpty
                ) {
                    generateSpeech()
                }

                // Audio player
                if generatedAudioData != nil {
                    HStack {
                        Button {
                            togglePlayback()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [DS.Cyan.primary, DS.Cyan.secondary], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 44, height: 44)
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .offset(x: isPlaying ? 0 : 2)
                            }
                        }
                        .buttonStyle(.plain)

                        // Waveform bars
                        HStack(spacing: 2) {
                            ForEach(0..<50, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(DS.Cyan.primary.opacity(0.6))
                                    .frame(width: 3, height: CGFloat.random(in: 8...30))
                            }
                        }
                        .frame(maxWidth: .infinity)

                        Button {
                            saveAudio()
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 20))
                                .foregroundStyle(DS.Cyan.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .background(DS.Surface.mid)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(DS.Border.subtle, lineWidth: 0.5))
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(DS.BG.primary)
        }
        .background(StudioBackground(accentColor: DS.Cyan.primary, glowOffsetX: 150, glowOffsetY: -80))
        .onAppear {
            checkModelStatus()
        }
    }

    // MARK: - Actions

    private func checkModelStatus() {
        Task {
            do {
                let kokoroLoaded = try await service.checkHealth()
                await MainActor.run {
                    if kokoroLoaded {
                        statusMessage = "Kokoro Ready"
                        isModelReady = true
                    } else {
                        statusMessage = "Kokoro loading..."
                        isModelReady = false
                    }
                }

                if kokoroLoaded {
                    await fetchVoicesFromServer()
                }
            } catch {
                await MainActor.run {
                    statusMessage = "Server not available"
                    isModelReady = false
                    isLoadingVoices = false
                }
            }
        }
    }

    private func fetchVoicesFromServer() async {
        do {
            let voicesData = try await service.fetchVoices()
            var newVoices: [String: [(id: String, name: String, gender: String)]] = [:]

            for (language, voices) in voicesData {
                let voiceList: [(id: String, name: String, gender: String)] = voices.map { voice in
                    return (id: voice.id, name: voice.name, gender: voice.gender)
                }
                if !voiceList.isEmpty {
                    newVoices[language] = voiceList
                }
            }

            await MainActor.run {
                voicesByLanguage = newVoices
                isLoadingVoices = false

                if selectedVoice.isEmpty || !voiceExists(selectedVoice, in: selectedLanguage) {
                    if let firstVoice = newVoices[selectedLanguage]?.first {
                        selectedVoice = firstVoice.id
                    } else if let anyLanguage = newVoices.keys.first,
                              let firstVoice = newVoices[anyLanguage]?.first {
                        selectedLanguage = anyLanguage
                        selectedVoice = firstVoice.id
                    }
                }

                let totalVoices = newVoices.values.reduce(0) { $0 + $1.count }
                statusMessage = "Kokoro Ready - \(totalVoices) voices"
            }
        } catch {
            await MainActor.run {
                isLoadingVoices = false
            }
        }
    }

    private func voiceExists(_ voiceId: String, in language: String) -> Bool {
        return voicesByLanguage[language]?.contains(where: { $0.id == voiceId }) ?? false
    }

    private func generateSpeech() {
        guard !text.isEmpty else { return }
        isGenerating = true

        Task {
            do {
                let data = try await service.synthesize(
                    text: text,
                    voice: selectedVoice,
                    speed: speed
                )

                await MainActor.run {
                    isGenerating = false
                    generatedAudioData = data
                    statusMessage = "Generated \(data.count / 1024) KB"

                    do {
                        audioPlayer = try AVAudioPlayer(data: data)
                        audioPlayer?.play()
                        isPlaying = true
                    } catch {
                        statusMessage = "Playback error: \(error.localizedDescription)"
                    }
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    statusMessage = "Error: \(error.localizedDescription)"
                }
            }
        }
    }

    private func togglePlayback() {
        if isPlaying {
            audioPlayer?.pause()
        } else {
            audioPlayer?.play()
        }
        isPlaying.toggle()
    }

    private func saveAudio() {
        // TODO: Save generated audio to file
    }
}

// MARK: - Voice Card

struct VoiceCard: View {
    let name: String
    let gender: String
    let isSelected: Bool
    let accentColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: gender == "female" ? "person.fill" : "person.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? accentColor : .secondary)
                Text(name)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? accentColor.opacity(0.12) : DS.Surface.dark)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? accentColor : DS.Border.subtle, lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    KokoroTTSView()
        .frame(width: 1000, height: 700)
}
