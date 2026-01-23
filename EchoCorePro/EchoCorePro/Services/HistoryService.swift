//
//  HistoryService.swift
//  EchoCorePro
//
//  Service for recording processing history to SwiftData
//

import Foundation
import SwiftData

/// Service for recording processing history entries
@MainActor
final class HistoryService {
    static let shared = HistoryService()
    private var modelContext: ModelContext?

    private init() {}

    /// Set the model context for SwiftData operations
    func setContext(_ context: ModelContext) {
        self.modelContext = context
    }

    /// Record a transcription (speech-to-text) operation
    func recordTranscription(
        modelName: String,
        inputLengthSeconds: Double,
        outputText: String,
        processingTimeMs: Int,
        confidence: Double? = nil
    ) {
        guard let context = modelContext else {
            OSLogManager.shared.log("HistoryService: No context set", category: .storage, level: .warning)
            return
        }

        let entry = ProcessingHistoryEntity(
            modelName: modelName,
            processingType: .speechToText,
            inputLength: inputLengthSeconds,
            outputLength: Double(outputText.count),
            processingTimeMs: processingTimeMs,
            confidence: confidence,
            textContent: outputText
        )

        context.insert(entry)
        try? context.save()
        OSLogManager.shared.log("Recorded transcription history: \(modelName)", category: .storage, level: .info)
    }

    /// Record a synthesis (text-to-speech) operation
    func recordSynthesis(
        modelName: String,
        inputText: String,
        outputDurationSeconds: Double,
        processingTimeMs: Int
    ) {
        guard let context = modelContext else {
            OSLogManager.shared.log("HistoryService: No context set", category: .storage, level: .warning)
            return
        }

        let entry = ProcessingHistoryEntity(
            modelName: modelName,
            processingType: .textToSpeech,
            inputLength: Double(inputText.count),
            outputLength: outputDurationSeconds,
            processingTimeMs: processingTimeMs,
            textContent: inputText
        )

        context.insert(entry)
        try? context.save()
        OSLogManager.shared.log("Recorded synthesis history: \(modelName)", category: .storage, level: .info)
    }

    /// Record an audio processing operation
    func recordAudioProcessing(
        inputDurationSeconds: Double,
        outputDurationSeconds: Double,
        processingTimeMs: Int,
        description: String? = nil
    ) {
        guard let context = modelContext else {
            OSLogManager.shared.log("HistoryService: No context set", category: .storage, level: .warning)
            return
        }

        let entry = ProcessingHistoryEntity(
            modelName: "Metal Audio Processor",
            processingType: .audioPostProcessing,
            inputLength: inputDurationSeconds,
            outputLength: outputDurationSeconds,
            processingTimeMs: processingTimeMs,
            textContent: description
        )

        context.insert(entry)
        try? context.save()
        OSLogManager.shared.log("Recorded audio processing history", category: .storage, level: .info)
    }

    /// Delete a history entry
    func deleteEntry(_ entry: ProcessingHistoryEntity) {
        guard let context = modelContext else { return }
        context.delete(entry)
        try? context.save()
    }

    /// Clear all history
    func clearAllHistory() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<ProcessingHistoryEntity>()
        if let entries = try? context.fetch(descriptor) {
            for entry in entries {
                context.delete(entry)
            }
            try? context.save()
        }
    }
}
