//
//  Models.swift
//  EchoCorePro
//

import Foundation

enum WorkspaceTab: String, CaseIterable, Identifiable {
    case tts = "Text to Speech"
    case stt = "Speech to Text"
    case status = "Status"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .tts: "speaker.wave.3.fill"
        case .stt: "waveform.and.mic"
        case .status: "chart.line.uptrend.xyaxis"
        }
    }
}

enum SpeechLanguage: String, CaseIterable, Identifiable, Codable {
    case english = "English"
    case italian = "Italian"
    case german = "German"
    case spanish = "Spanish"
    case french = "French"
    case hindi = "Hindi"
    case dutch = "Dutch"
    case portuguese = "Portuguese"
    case arabic = "Arabic"
    case slovenian = "Slovenian"

    var id: String { rawValue }

    var backendCode: String {
        switch self {
        case .english: "en"
        case .italian: "it"
        case .german: "de"
        case .spanish: "es"
        case .french: "fr"
        case .hindi: "hi"
        case .dutch: "nl"
        case .portuguese: "pt"
        case .arabic: "ar"
        case .slovenian: "sl"
        }
    }

    var usesPiper: Bool {
        self == .slovenian
    }
}

struct BackendHealth: Codable, Equatable {
    var status: String
    var ready: Bool
    var voxtralLoaded: Bool
    var sttReady: Bool
    var modelsReady: Bool?
    var modelsRoot: String
    var uptimeSeconds: Double
    var serverPID: Int?
    var parentPID: Int?

    enum CodingKeys: String, CodingKey {
        case status
        case ready
        case voxtralLoaded = "voxtral_loaded"
        case sttReady = "stt_ready"
        case modelsReady = "models_ready"
        case modelsRoot = "models_root"
        case uptimeSeconds = "uptime_seconds"
        case serverPID = "server_pid"
        case parentPID = "parent_pid"
    }

    static let offline = BackendHealth(
        status: "offline",
        ready: false,
        voxtralLoaded: false,
        sttReady: false,
        modelsReady: false,
        modelsRoot: "",
        uptimeSeconds: 0,
        serverPID: nil,
        parentPID: nil
    )
}

struct VoiceCatalogResponse: Codable {
    var voicesByLanguage: [String: [String]]

    enum CodingKeys: String, CodingKey {
        case voicesByLanguage = "voices_by_language"
    }
}

struct TTSRequest: Codable {
    var text: String
    var language: String
    var voice: String
    var speed: Double
}

struct STTResponse: Codable {
    var text: String
    var language: String?
    var durationSeconds: Double?

    enum CodingKeys: String, CodingKey {
        case text
        case language
        case durationSeconds = "duration_seconds"
    }
}

struct ActivityItem: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var detail: String
    var date = Date()
}
