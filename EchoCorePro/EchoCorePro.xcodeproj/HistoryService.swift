//
//  HistoryService.swift
//  EchoCorePro
//
//  Service for managing processing history with SwiftData
//

import Foundation
import SwiftData

/// Service for managing processing history
@MainActor
final class HistoryService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = HistoryService()
    
    // MARK: - Properties
    
    private var modelContext: ModelContext?
    private let logger = OSLogManager.shared
    
    // MARK: - Initialization
    
    private init() {
        logger.log("HistoryService initialized", category: .lifecycle, level: .info)
    }
    
    /// Set the SwiftData model context
    func setContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - Recording History
    
    /// Record a transcription operation
    func recordTranscription(
        modelName: String,
        inputLengthSeconds: TimeInterval,
        outputText: String,
        processingTimeMs: Int64,
        confidence: Double?
    ) {
        guard let context = modelContext else {
            logger.log("Cannot record history: no model context", category: .storage, level: .error)
            return
        }
        
        let entry = ProcessingHistoryEntity(
            processingType: .speechToText,
            modelName: modelName,
            inputLength: inputLengthSeconds,
            textContent: outputText,
            processingTimeMs: processingTimeMs,
            confidence: confidence,
            realTimeFactor: Double(processingTimeMs) / 1000.0 / inputLengthSeconds
        )
        
        context.insert(entry)
        
        do {
            try context.save()
            logger.log("Recorded transcription history", category: .storage, level: .debug)
        } catch {
            logger.log("Failed to save history: \(error)", category: .storage, level: .error)
        }
    }
    
    /// Record a text-to-speech operation
    func recordTTS(
        modelName: String,
        inputTextLength: Int,
        outputAudioPath: String,
        processingTimeMs: Int64
    ) {
        guard let context = modelContext else {
            logger.log("Cannot record history: no model context", category: .storage, level: .error)
            return
        }
        
        let entry = ProcessingHistoryEntity(
            processingType: .textToSpeech,
            modelName: modelName,
            inputLength: Double(inputTextLength),
            audioFilePath: outputAudioPath,
            processingTimeMs: processingTimeMs
        )
        
        context.insert(entry)
        
        do {
            try context.save()
            logger.log("Recorded TTS history", category: .storage, level: .debug)
        } catch {
            logger.log("Failed to save history: \(error)", category: .storage, level: .error)
        }
    }
    
    /// Record an audio post-processing operation
    func recordAudioProcessing(
        modelName: String,
        inputLengthSeconds: TimeInterval,
        outputAudioPath: String,
        processingTimeMs: Int64
    ) {
        guard let context = modelContext else {
            logger.log("Cannot record history: no model context", category: .storage, level: .error)
            return
        }
        
        let entry = ProcessingHistoryEntity(
            processingType: .audioPostProcessing,
            modelName: modelName,
            inputLength: inputLengthSeconds,
            audioFilePath: outputAudioPath,
            processingTimeMs: processingTimeMs,
            realTimeFactor: Double(processingTimeMs) / 1000.0 / inputLengthSeconds
        )
        
        context.insert(entry)
        
        do {
            try context.save()
            logger.log("Recorded audio processing history", category: .storage, level: .debug)
        } catch {
            logger.log("Failed to save history: \(error)", category: .storage, level: .error)
        }
    }
    
    // MARK: - History Management
    
    /// Delete a specific history entry
    func deleteEntry(_ entry: ProcessingHistoryEntity) {
        guard let context = modelContext else { return }
        
        // Delete associated files if they exist
        if let audioPath = entry.audioFilePath {
            try? FileManager.default.removeItem(atPath: audioPath)
        }
        
        context.delete(entry)
        
        do {
            try context.save()
            logger.log("Deleted history entry", category: .storage, level: .debug)
        } catch {
            logger.log("Failed to delete history: \(error)", category: .storage, level: .error)
        }
    }
    
    /// Clear all history
    func clearAllHistory() {
        guard let context = modelContext else { return }
        
        do {
            // Fetch all history entries
            let descriptor = FetchDescriptor<ProcessingHistoryEntity>()
            let entries = try context.fetch(descriptor)
            
            // Delete associated files
            for entry in entries {
                if let audioPath = entry.audioFilePath {
                    try? FileManager.default.removeItem(atPath: audioPath)
                }
                context.delete(entry)
            }
            
            try context.save()
            logger.log("Cleared all history (\(entries.count) entries)", category: .storage, level: .info)
        } catch {
            logger.log("Failed to clear history: \(error)", category: .storage, level: .error)
        }
    }
    
    /// Get history statistics
    func getStatistics() -> HistoryStatistics {
        guard let context = modelContext else {
            return HistoryStatistics(totalOperations: 0, totalProcessingTimeMs: 0, averageConfidence: 0)
        }
        
        do {
            let descriptor = FetchDescriptor<ProcessingHistoryEntity>()
            let entries = try context.fetch(descriptor)
            
            let totalOps = entries.count
            let totalTime = entries.reduce(0) { $0 + $1.processingTimeMs }
            let confidenceSum = entries.compactMap { $0.confidence }.reduce(0, +)
            let confidenceCount = entries.filter { $0.confidence != nil }.count
            let avgConfidence = confidenceCount > 0 ? confidenceSum / Double(confidenceCount) : 0
            
            return HistoryStatistics(
                totalOperations: totalOps,
                totalProcessingTimeMs: totalTime,
                averageConfidence: avgConfidence
            )
        } catch {
            logger.log("Failed to get statistics: \(error)", category: .storage, level: .error)
            return HistoryStatistics(totalOperations: 0, totalProcessingTimeMs: 0, averageConfidence: 0)
        }
    }
}

// MARK: - Statistics Type

struct HistoryStatistics {
    let totalOperations: Int
    let totalProcessingTimeMs: Int64
    let averageConfidence: Double
}
