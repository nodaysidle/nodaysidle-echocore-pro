//
//  DownloadJobEntity.swift
//  EchoCorePro
//
//  SwiftData model for tracking download jobs
//

import Foundation
import SwiftData

/// Status of a download job
enum DownloadStatus: String, Codable {
    case pending = "Pending"
    case downloading = "Downloading"
    case paused = "Paused"
    case completed = "Completed"
    case failed = "Failed"
    case cancelled = "Cancelled"
}

/// Represents a model download job
@Model
final class DownloadJobEntity {
    /// Unique identifier
    @Attribute(.unique) var id: UUID
    
    /// Model identifier (HuggingFace ID)
    var modelId: String
    
    /// Display name
    var modelName: String
    
    /// Download status
    var statusRaw: String
    
    /// Progress (0.0 to 1.0)
    var progress: Double
    
    /// Bytes downloaded
    var bytesDownloaded: Int64
    
    /// Total bytes to download
    var totalBytes: Int64
    
    /// Download start time
    var startTime: Date
    
    /// Download completion time
    var completionTime: Date?
    
    /// Error message if failed
    var errorMessage: String?
    
    /// Local file path when completed
    var localFilePath: String?
    
    // MARK: - Computed Properties
    
    var status: DownloadStatus {
        get { DownloadStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
    
    var progressPercent: Int {
        Int(progress * 100)
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        modelId: String,
        modelName: String,
        status: DownloadStatus = .pending,
        progress: Double = 0.0,
        bytesDownloaded: Int64 = 0,
        totalBytes: Int64 = 0,
        startTime: Date = Date(),
        completionTime: Date? = nil,
        errorMessage: String? = nil,
        localFilePath: String? = nil
    ) {
        self.id = id
        self.modelId = modelId
        self.modelName = modelName
        self.statusRaw = status.rawValue
        self.progress = progress
        self.bytesDownloaded = bytesDownloaded
        self.totalBytes = totalBytes
        self.startTime = startTime
        self.completionTime = completionTime
        self.errorMessage = errorMessage
        self.localFilePath = localFilePath
    }
}
