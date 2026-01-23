//
//  ProcessingHistoryEntity.swift
//  EchoCorePro
//
//  SwiftData model for processing history (transcriptions, TTS, etc.)
//

import Foundation
import SwiftData

/// Type of processing operation
enum ProcessingType: String, Codable, CaseIterable {
    case speechToText = "Speech to Text"
    case textToSpeech = "Text to Speech"
    case audioPostProcessing = "Audio Post-Processing"
    
    var icon: String {
        switch self {
        case .speechToText: return "mic.fill"
        case .textToSpeech: return "speaker.wave.3.fill"
        case .audioPostProcessing: return "waveform.badge.magnifyingglass"
        }
    }
}

/// Represents a processing history entry
@Model
final class ProcessingHistoryEntity {
    /// Unique identifier
    @Attribute(.unique) var id: UUID
    
    /// Type of processing
    var processingTypeRaw: String
    
    /// Model name used
    var modelName: String
    
    /// Timestamp of the operation
    var timestamp: Date
    
    /// Input length (seconds for audio, characters for text)
    var inputLength: Double
    
    /// Output text (for STT) or input text (for TTS)
    var textContent: String?
    
    /// Output audio file path (for TTS)
    var audioFilePath: String?
    
    /// Processing time in milliseconds
    var processingTimeMs: Int64
    
    /// Confidence score (0.0 to 1.0) for STT
    var confidence: Double?
    
    /// Real-time factor (processing_time / audio_duration)
    var realTimeFactor: Double
    
    /// Whether the operation was successful
    var wasSuccessful: Bool
    
    /// Error message if failed
    var errorMessage: String?
    
    // MARK: - Computed Properties
    
    var processingType: ProcessingType {
        get { ProcessingType(rawValue: processingTypeRaw) ?? .speechToText }
        set { processingTypeRaw = newValue.rawValue }
    }
    
    var inputLengthFormatted: String {
        if processingType == .speechToText || processingType == .audioPostProcessing {
            return String(format: "%.1fs", inputLength)
        } else {
            return "\(Int(inputLength)) chars"
        }
    }
    
    var processingTimeFormatted: String {
        if processingTimeMs < 1000 {
            return "\(processingTimeMs)ms"
        } else {
            return String(format: "%.2fs", Double(processingTimeMs) / 1000.0)
        }
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        processingType: ProcessingType,
        modelName: String,
        timestamp: Date = Date(),
        inputLength: Double,
        textContent: String? = nil,
        audioFilePath: String? = nil,
        processingTimeMs: Int64,
        confidence: Double? = nil,
        realTimeFactor: Double = 0.0,
        wasSuccessful: Bool = true,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.processingTypeRaw = processingType.rawValue
        self.modelName = modelName
        self.timestamp = timestamp
        self.inputLength = inputLength
        self.textContent = textContent
        self.audioFilePath = audioFilePath
        self.processingTimeMs = processingTimeMs
        self.confidence = confidence
        self.realTimeFactor = realTimeFactor
        self.wasSuccessful = wasSuccessful
        self.errorMessage = errorMessage
    }
}
