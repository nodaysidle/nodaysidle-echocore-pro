//
//  ModelRegistry.swift
//  EchoCorePro
//
//  Registry of available voice models
//

import Foundation

/// Information about an available model
struct AvailableModel: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let type: ModelType
    let sizeBytes: Int64
    let downloadURL: URL
    let version: String
    let languages: [String]
    let checksum: String?

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

/// Registry providing available models for download
struct ModelRegistry {

    /// Models that actually work on 16GB M4 Mac Mini
    static let availableModels: [AvailableModel] = [
        // Piper TTS — fast, lightweight, 100+ voices
        AvailableModel(
            id: "rhasspy/piper",
            name: "Piper TTS",
            description: "Ultra-fast TTS with 100+ voices across 13+ languages. Runs via Python server.",
            type: .tts,
            sizeBytes: 50_000_000,
            downloadURL: URL(
                string: "https://github.com/rhasspy/piper/releases")!,
            version: "2024.11",
            languages: ["en", "de", "fr", "es", "it", "pt", "nl", "pl", "ru", "zh", "ja", "ko"],
            checksum: nil
        ),

        // Qwen3-TTS 0.6B 8-bit — voice cloning via MLX (fits 16GB RAM)
        AvailableModel(
            id: "mlx-community/Qwen3-TTS-12Hz-0.6B-Base-8bit",
            name: "Qwen3-TTS 0.6B (Voice Cloning)",
            description: "Voice cloning from ~6 seconds of audio. 0.6B params, 8-bit quantized for 16GB RAM. Runs via MLX.",
            type: .voiceCloning,
            sizeBytes: 700_000_000,
            downloadURL: URL(
                string: "https://huggingface.co/mlx-community/Qwen3-TTS-12Hz-0.6B-Base-8bit")!,
            version: "1.0",
            languages: ["en", "it", "de", "fr", "es", "pt", "ru", "zh", "ja", "ko"],
            checksum: nil
        ),
    ]

    /// Get models by type
    static func models(ofType type: ModelType) -> [AvailableModel] {
        availableModels.filter { $0.type == type }
    }

    /// Search models by name or description
    static func search(query: String) -> [AvailableModel] {
        guard !query.isEmpty else { return availableModels }
        let lowercased = query.lowercased()
        return availableModels.filter {
            $0.name.lowercased().contains(lowercased)
                || $0.description.lowercased().contains(lowercased)
        }
    }

    /// Get model by ID
    static func model(withId id: String) -> AvailableModel? {
        availableModels.first { $0.id == id }
    }
}
