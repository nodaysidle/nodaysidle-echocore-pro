//
//  TTSView.swift
//  EchoCorePro
//

import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

struct TTSView: View {
    @EnvironmentObject private var backend: BackendManager
    @State private var voicesByLanguage: [String: [String]] = [:]
    @State private var language: SpeechLanguage = .english
    @State private var voice = "casual_female"
    @State private var text = "EchoCore Pro is running local speech synthesis with Voxtral on Apple Silicon."
    @State private var speed = 1.0
    @State private var isGenerating = false
    @State private var status = "Ready"
    @State private var audioData: Data?
    @State private var waveformSamples: [CGFloat] = []
    @State private var player: AVAudioPlayer?

    private var voices: [String] {
        voicesByLanguage[language.rawValue] ?? defaultVoices(for: language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            HStack(alignment: .top, spacing: 16) {
                controlPanel
                    .frame(width: 300)

                VStack(alignment: .leading, spacing: 14) {
                    TextEditor(text: $text)
                        .font(.title3)
                        .scrollContentBackground(.hidden)
                        .padding(14)
                        .frame(minHeight: 280)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.10), lineWidth: 1))

                    HStack {
                        Button {
                            generate()
                        } label: {
                            Label(isGenerating ? "Generating" : "Generate", systemImage: "speaker.wave.2.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isGenerating || !backend.health.ready || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || voice.isEmpty)

                        Button {
                            play()
                        } label: {
                            Label("Play", systemImage: "play.fill")
                        }
                        .disabled(audioData == nil)

                        Button {
                            save()
                        } label: {
                            Label("Save", systemImage: "square.and.arrow.down")
                        }
                        .disabled(audioData == nil)

                        Spacer()

                        Text(status)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    WaveformStrip(active: audioData != nil, samples: waveformSamples)
                        .frame(height: 92)
                        .glassPanel()
                }
            }
        }
        .padding(24)
        .task {
            await loadVoices()
        }
        .onChange(of: language) { _, _ in
            voice = voices.first ?? ""
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Text to Speech")
                    .font(.largeTitle.weight(.semibold))
                Text("Voxtral is used for bundled multilingual voices. Slovenian routes to the bundled Piper voice.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            MetricPill(title: "Engine", value: language.usesPiper ? "Piper Slovenian" : "Voxtral 4bit", color: ECTheme.cyan)
        }
    }

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Language")
                    .font(.headline)
                Picker("Language", selection: $language) {
                    ForEach(SpeechLanguage.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.menu)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Voice")
                    .font(.headline)
                Picker("Voice", selection: $voice) {
                    ForEach(voices, id: \.self) { item in
                        Text(item.replacingOccurrences(of: "_", with: " ")).tag(item)
                    }
                }
                .pickerStyle(.menu)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Speed")
                    Spacer()
                    Text(String(format: "%.1fx", speed))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $speed, in: 0.7...1.4, step: 0.1)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("Bundled on first launch", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(ECTheme.mint)
                Text("Voxtral, Whisper small q4, and Slovenian Piper files are inside the application bundle.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .glassPanel()
    }

    private func loadVoices() async {
        do {
            voicesByLanguage = try await backend.voices()
            voice = voices.first ?? ""
        } catch {
            status = error.localizedDescription
        }
    }

    private func generate() {
        isGenerating = true
        status = language == .slovenian ? "Running Piper" : "Running Voxtral"

        Task {
            do {
                let data = try await backend.synthesize(text: text, language: language, voice: voice, speed: speed)
                let samples = await Task.detached(priority: .utility) {
                    WaveformAnalyzer.samples(from: data, count: 92)
                }.value
                await MainActor.run {
                    audioData = data
                    waveformSamples = samples
                    player = try? AVAudioPlayer(data: data)
                    player?.play()
                    status = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    status = error.localizedDescription
                    isGenerating = false
                }
            }
        }
    }

    private func play() {
        if player == nil, let audioData {
            player = try? AVAudioPlayer(data: audioData)
        }
        player?.play()
    }

    private func save() {
        guard let audioData else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.wav]
        panel.nameFieldStringValue = "echocore-tts.wav"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try audioData.write(to: url)
                status = "Saved \(url.lastPathComponent)"
            } catch {
                status = error.localizedDescription
            }
        }
    }

    private func defaultVoices(for language: SpeechLanguage) -> [String] {
        switch language {
        case .english:
            ["casual_female", "casual_male", "cheerful_female", "neutral_female", "neutral_male"]
        case .italian:
            ["it_female", "it_male"]
        case .german:
            ["de_female", "de_male"]
        case .spanish:
            ["es_female", "es_male"]
        case .french:
            ["fr_female", "fr_male"]
        case .hindi:
            ["hi_female", "hi_male"]
        case .dutch:
            ["nl_female", "nl_male"]
        case .portuguese:
            ["pt_female", "pt_male"]
        case .arabic:
            ["ar_male"]
        case .slovenian: ["sl_SI-artur-medium"]
        }
    }
}

private struct WaveformStrip: View {
    let active: Bool
    let samples: [CGFloat]

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<92, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(active ? ECTheme.cyan.opacity(0.72) : Color.secondary.opacity(0.18))
                    .frame(width: 4, height: barHeight(at: index))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func barHeight(at index: Int) -> CGFloat {
        guard active, index < samples.count else {
            return CGFloat(12 + ((index * 19) % 52))
        }
        return max(8, min(72, samples[index] * 72))
    }
}

private enum WaveformAnalyzer {
    static func samples(from data: Data, count: Int) -> [CGFloat] {
        guard count > 0, data.count > 44 else {
            return []
        }

        return data.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
                return []
            }

            func ascii(_ offset: Int, _ length: Int) -> String {
                guard offset + length <= data.count else { return "" }
                return String(bytes: UnsafeBufferPointer(start: base + offset, count: length), encoding: .ascii) ?? ""
            }

            func uint16(_ offset: Int) -> UInt16 {
                guard offset + 2 <= data.count else { return 0 }
                return UInt16(base[offset]) | (UInt16(base[offset + 1]) << 8)
            }

            func uint32(_ offset: Int) -> UInt32 {
                guard offset + 4 <= data.count else { return 0 }
                return UInt32(base[offset])
                    | (UInt32(base[offset + 1]) << 8)
                    | (UInt32(base[offset + 2]) << 16)
                    | (UInt32(base[offset + 3]) << 24)
            }

            guard ascii(0, 4) == "RIFF", ascii(8, 4) == "WAVE" else {
                return []
            }

            var offset = 12
            var channels = 1
            var bitsPerSample = 16
            var dataOffset: Int?
            var dataSize = 0

            while offset + 8 <= data.count {
                let chunkID = ascii(offset, 4)
                let chunkSize = Int(uint32(offset + 4))
                let chunkDataOffset = offset + 8

                if chunkID == "fmt ", chunkDataOffset + 16 <= data.count {
                    channels = max(1, Int(uint16(chunkDataOffset + 2)))
                    bitsPerSample = Int(uint16(chunkDataOffset + 14))
                } else if chunkID == "data" {
                    dataOffset = chunkDataOffset
                    dataSize = min(chunkSize, data.count - chunkDataOffset)
                    break
                }

                offset = chunkDataOffset + chunkSize + (chunkSize % 2)
            }

            guard bitsPerSample == 16, let dataOffset, dataSize > 0 else {
                return []
            }

            let bytesPerSample = 2
            let frameCount = dataSize / (bytesPerSample * channels)
            guard frameCount > 0 else {
                return []
            }

            var buckets = Array(repeating: CGFloat(0), count: count)
            for frame in 0..<frameCount {
                let bucket = min(count - 1, frame * count / frameCount)
                var peak = CGFloat(0)

                for channel in 0..<channels {
                    let sampleOffset = dataOffset + ((frame * channels + channel) * bytesPerSample)
                    guard sampleOffset + 1 < data.count else {
                        continue
                    }
                    let raw = Int16(bitPattern: uint16(sampleOffset))
                    peak = max(peak, CGFloat(abs(Int(raw))) / CGFloat(Int16.max))
                }

                buckets[bucket] = max(buckets[bucket], peak)
            }

            return buckets
        }
    }
}
