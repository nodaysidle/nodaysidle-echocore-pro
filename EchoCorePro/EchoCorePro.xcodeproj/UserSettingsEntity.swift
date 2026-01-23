//
//  UserSettingsEntity.swift
//  EchoCorePro
//
//  SwiftData model for user settings/preferences
//

import Foundation
import SwiftData

/// User settings and preferences
@Model
final class UserSettingsEntity {
    /// Unique identifier (singleton pattern - only one settings object)
    @Attribute(.unique) var id: UUID
    
    /// Default model ID for STT
    var defaultSTTModelId: UUID?
    
    /// Default model ID for TTS
    var defaultTTSModelId: UUID?
    
    /// Auto-quantize downloaded models
    var autoQuantize: Bool
    
    /// Preferred quantization type
    var preferredQuantizationType: String?
    
    /// Memory limit in MB
    var memoryLimitMB: Int
    
    /// Enable global hotkeys
    var hotkeysEnabled: Bool
    
    /// Download location path
    var downloadLocationPath: String
    
    /// Auto-start server on launch
    var autoStartServer: Bool
    
    /// Server port
    var serverPort: Int
    
    /// Enable audio processing by default
    var enableAudioProcessing: Bool
    
    /// De-esser settings
    var deEsserEnabled: Bool
    var deEsserThreshold: Float
    
    /// Noise gate settings
    var noiseGateEnabled: Bool
    var noiseGateThreshold: Float
    
    /// Compressor settings
    var compressorEnabled: Bool
    var compressorRatio: Float
    
    /// High-pass filter settings
    var highPassEnabled: Bool
    var highPassCutoff: Float
    
    /// Last updated timestamp
    var lastUpdated: Date
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        defaultSTTModelId: UUID? = nil,
        defaultTTSModelId: UUID? = nil,
        autoQuantize: Bool = true,
        preferredQuantizationType: String? = nil,
        memoryLimitMB: Int = 2048,
        hotkeysEnabled: Bool = true,
        downloadLocationPath: String = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.path,
        autoStartServer: Bool = false,
        serverPort: Int = 8765,
        enableAudioProcessing: Bool = true,
        deEsserEnabled: Bool = true,
        deEsserThreshold: Float = 0.3,
        noiseGateEnabled: Bool = true,
        noiseGateThreshold: Float = -40,
        compressorEnabled: Bool = true,
        compressorRatio: Float = 4.0,
        highPassEnabled: Bool = true,
        highPassCutoff: Float = 80,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.defaultSTTModelId = defaultSTTModelId
        self.defaultTTSModelId = defaultTTSModelId
        self.autoQuantize = autoQuantize
        self.preferredQuantizationType = preferredQuantizationType
        self.memoryLimitMB = memoryLimitMB
        self.hotkeysEnabled = hotkeysEnabled
        self.downloadLocationPath = downloadLocationPath
        self.autoStartServer = autoStartServer
        self.serverPort = serverPort
        self.enableAudioProcessing = enableAudioProcessing
        self.deEsserEnabled = deEsserEnabled
        self.deEsserThreshold = deEsserThreshold
        self.noiseGateEnabled = noiseGateEnabled
        self.noiseGateThreshold = noiseGateThreshold
        self.compressorEnabled = compressorEnabled
        self.compressorRatio = compressorRatio
        self.highPassEnabled = highPassEnabled
        self.highPassCutoff = highPassCutoff
        self.lastUpdated = lastUpdated
    }
}
