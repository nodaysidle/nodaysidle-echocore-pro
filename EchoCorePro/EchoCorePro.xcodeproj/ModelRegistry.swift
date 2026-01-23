//
//  ModelRegistry.swift
//  EchoCorePro
//
//  Registry of available models for download
//

import Foundation

/// Represents an available model that can be downloaded
struct AvailableModel: Identifiable, Codable {
    let id: String  // HuggingFace model ID
    let name: String
    let description: String
    let type: ModelType
    let version: String
    let sizeBytes: Int64
    let languages: [String]
    let requiresGPU: Bool
    let recommendedRAM: Int  // in MB
    
    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

/// Central registry of all available models
struct ModelRegistry {
    /// All available models that can be downloaded
    static let availableModels: [AvailableModel] = [
        // TODO: Populate with actual models from HuggingFace or your model repository
        
        // Speech-to-Text Models
        AvailableModel(
            id: "openai/whisper-tiny",
            name: "Whisper Tiny",
            description: "Smallest Whisper model. Fast inference with decent accuracy.",
            type: .stt,
            version: "1.0",
            sizeBytes: 75_000_000,  // ~75 MB
            languages: ["en", "multilingual"],
            requiresGPU: false,
            recommendedRAM: 512
        ),
        
        AvailableModel(
            id: "openai/whisper-base",
            name: "Whisper Base",
            description: "Balanced speed and accuracy for speech recognition.",
            type: .stt,
            version: "1.0",
            sizeBytes: 145_000_000,  // ~145 MB
            languages: ["en", "multilingual"],
            requiresGPU: false,
            recommendedRAM: 1024
        ),
        
        AvailableModel(
            id: "openai/whisper-small",
            name: "Whisper Small",
            description: "Good accuracy with reasonable speed.",
            type: .stt,
            version: "1.0",
            sizeBytes: 488_000_000,  // ~488 MB
            languages: ["en", "multilingual"],
            requiresGPU: false,
            recommendedRAM: 2048
        ),
        
        AvailableModel(
            id: "openai/whisper-medium",
            name: "Whisper Medium",
            description: "High accuracy for most use cases.",
            type: .stt,
            version: "1.0",
            sizeBytes: 1_540_000_000,  // ~1.54 GB
            languages: ["en", "multilingual"],
            requiresGPU: true,
            recommendedRAM: 4096
        ),
        
        AvailableModel(
            id: "openai/whisper-large-v3",
            name: "Whisper Large v3",
            description: "State-of-the-art accuracy. Best quality transcription.",
            type: .stt,
            version: "3.0",
            sizeBytes: 3_100_000_000,  // ~3.1 GB
            languages: ["en", "multilingual"],
            requiresGPU: true,
            recommendedRAM: 8192
        ),
        
        // Text-to-Speech Models
        AvailableModel(
            id: "microsoft/speecht5_tts",
            name: "SpeechT5 TTS",
            description: "Fast and natural English text-to-speech.",
            type: .tts,
            version: "1.0",
            sizeBytes: 400_000_000,  // ~400 MB
            languages: ["en"],
            requiresGPU: false,
            recommendedRAM: 2048
        ),
        
        AvailableModel(
            id: "suno/bark",
            name: "Bark",
            description: "Expressive TTS with emotion support. Supports [laughs], [sighs].",
            type: .tts,
            version: "1.0",
            sizeBytes: 1_200_000_000,  // ~1.2 GB
            languages: ["en", "multilingual"],
            requiresGPU: true,
            recommendedRAM: 4096
        ),
        
        // Voice Cloning Models
        AvailableModel(
            id: "coqui/xtts-v2",
            name: "XTTS v2",
            description: "High-quality voice cloning from short samples.",
            type: .voiceCloning,
            version: "2.0",
            sizeBytes: 1_800_000_000,  // ~1.8 GB
            languages: ["en", "es", "fr", "de", "it", "pt", "pl", "tr", "ru", "nl", "cs", "ar", "zh", "ja", "hu", "ko"],
            requiresGPU: true,
            recommendedRAM: 6144
        ),
    ]
    
    /// Find a model by its ID
    static func model(withId id: String) -> AvailableModel? {
        availableModels.first { $0.id == id }
    }
    
    /// Get models filtered by type
    static func models(ofType type: ModelType) -> [AvailableModel] {
        availableModels.filter { $0.type == type }
    }
}
