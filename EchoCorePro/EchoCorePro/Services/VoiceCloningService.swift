//
//  VoiceCloningService.swift
//  EchoCorePro
//
//  Swift client for TTS server (Qwen3-TTS + Kokoro)
//

import Combine
import Foundation

// MARK: - Constants

private enum ServiceConstants {
    static let baseURL = URL(string: "http://127.0.0.1:8765")!
    static let requestTimeout: TimeInterval = 600  // 1.7B model needs more time per chunk
    static let resourceTimeout: TimeInterval = 1200
    static let healthCacheTTL: TimeInterval = 5.0
    static let wavHeaderMinSize = 44
}

// MARK: - Kokoro TTS Service

/// Service for Kokoro TTS via the local Python server
actor KokoroTTSService {

    struct HealthResponse: Codable {
        let kokoroLoaded: Bool

        enum CodingKeys: String, CodingKey {
            case kokoroLoaded = "kokoro_loaded"
        }
    }

    struct VoiceInfo: Codable, Identifiable, Sendable {
        let id: String
        let name: String
        let gender: String
    }

    struct VoicesResponse: Codable {
        let voicesByLanguage: [String: [VoiceInfo]]

        enum CodingKeys: String, CodingKey {
            case voicesByLanguage = "voices_by_language"
        }
    }

    private struct SynthesizeRequest: Encodable {
        let text: String
        let voice: String
        let speed: Double
    }

    private let urlSession: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = ServiceConstants.requestTimeout
        config.timeoutIntervalForResource = ServiceConstants.resourceTimeout
        self.urlSession = URLSession(configuration: config)
    }

    func checkHealth() async throws -> Bool {
        let url = ServiceConstants.baseURL.appendingPathComponent("health")
        let (data, response) = try await urlSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return false
        }

        let health = try JSONDecoder().decode(HealthResponse.self, from: data)
        return health.kokoroLoaded
    }

    func fetchVoices() async throws -> [String: [VoiceInfo]] {
        let url = ServiceConstants.baseURL.appendingPathComponent("kokoro/voices")
        let (data, response) = try await urlSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return [:]
        }

        let voices = try JSONDecoder().decode(VoicesResponse.self, from: data)
        return voices.voicesByLanguage
    }

    func synthesize(
        text: String,
        voice: String,
        speed: Double
    ) async throws -> Data {
        let url = ServiceConstants.baseURL.appendingPathComponent("kokoro/synthesize")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            SynthesizeRequest(text: text, voice: voice, speed: speed)
        )

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceCloningService.VoiceCloningError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
               let error = errorData["error"] {
                throw VoiceCloningService.VoiceCloningError.synthesizeFailed(error)
            }
            throw VoiceCloningService.VoiceCloningError.synthesizeFailed("Status \(httpResponse.statusCode)")
        }

        guard data.count > ServiceConstants.wavHeaderMinSize else {
            throw VoiceCloningService.VoiceCloningError.invalidAudio
        }

        return data
    }
}

// MARK: - Voice Cloning Service (Qwen3-TTS)

/// Service for voice cloning via Qwen3-TTS
actor VoiceCloningService: ServiceProtocol {

    nonisolated let serviceId = "VoiceCloningService"

    // MARK: - Properties

    private let urlSession: URLSession
    private let logger = OSLogManager.shared

    // Health check cache
    private var lastHealthCheck: (date: Date, healthy: Bool)?

    // MARK: - Types

    struct CloneResponse: Codable {
        let speakerId: String
        let durationSeconds: Double
        let success: Bool
        let message: String

        enum CodingKeys: String, CodingKey {
            case speakerId = "speaker_id"
            case durationSeconds = "duration_seconds"
            case success, message
        }
    }

    struct HealthResponse: Codable {
        let status: String
        let qwen3Loaded: Bool
        let kokoroLoaded: Bool
        let speakersCount: Int

        enum CodingKeys: String, CodingKey {
            case status
            case qwen3Loaded = "qwen3_loaded"
            case kokoroLoaded = "kokoro_loaded"
            case speakersCount = "speakers_count"
        }
    }

    struct SpeakerInfo: Codable {
        let id: String
        let duration: Double
    }

    struct SpeakersResponse: Codable {
        let speakers: [SpeakerInfo]
        let count: Int
    }

    enum VoiceCloningError: Error, LocalizedError {
        case serverNotRunning
        case modelNotLoaded
        case cloneFailed(String)
        case synthesizeFailed(String)
        case speakerNotFound(String)
        case invalidAudio
        case networkError(String)

        var errorDescription: String? {
            switch self {
            case .serverNotRunning:
                return "TTS server is not running. Start it with: python Scripts/tts_server.py"
            case .modelNotLoaded:
                return "Qwen3-TTS model not loaded on server"
            case .cloneFailed(let reason):
                return "Voice cloning failed: \(reason)"
            case .synthesizeFailed(let reason):
                return "Speech synthesis failed: \(reason)"
            case .speakerNotFound(let id):
                return "Speaker '\(id)' not found. Clone a voice first."
            case .invalidAudio:
                return "Invalid or empty audio data"
            case .networkError(let reason):
                return "Network error: \(reason)"
            }
        }
    }

    // MARK: - Initialization

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = ServiceConstants.requestTimeout
        config.timeoutIntervalForResource = ServiceConstants.resourceTimeout
        self.urlSession = URLSession(configuration: config)
    }

    // MARK: - ServiceProtocol

    func initialize() async throws {
        let isHealthy = await checkHealth()
        if isHealthy {
            logger.log("VoiceCloningService connected to TTS server", category: .inference, level: .info)
        } else {
            logger.log("VoiceCloningService: TTS server not available", category: .inference, level: .warning)
        }
    }

    func shutdown() async {
        logger.log("VoiceCloningService shutdown", category: .inference, level: .info)
    }

    // MARK: - Health Check with Caching

    /// Check if the server is running (with caching)
    func checkHealth() async -> Bool {
        // Return cached result if fresh
        if let cached = lastHealthCheck,
           Date().timeIntervalSince(cached.date) < ServiceConstants.healthCacheTTL {
            return cached.healthy
        }

        do {
            let url = ServiceConstants.baseURL.appendingPathComponent("health")
            let (data, response) = try await urlSession.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                lastHealthCheck = (Date(), false)
                return false
            }

            let health = try JSONDecoder().decode(HealthResponse.self, from: data)
            let healthy = health.status == "healthy" || health.qwen3Loaded
            lastHealthCheck = (Date(), healthy)
            return healthy
        } catch {
            lastHealthCheck = (Date(), false)
            return false
        }
    }

    /// Check if Qwen3-TTS model is loaded
    func isModelLoaded() async -> Bool {
        do {
            let url = ServiceConstants.baseURL.appendingPathComponent("health")
            let (data, _) = try await urlSession.data(from: url)
            let health = try JSONDecoder().decode(HealthResponse.self, from: data)
            return health.qwen3Loaded
        } catch {
            return false
        }
    }

    // MARK: - Voice Cloning

    /// Clone a voice from an audio file
    func cloneVoice(from audioURL: URL, speakerId: String) async throws -> CloneResponse {
        guard await checkHealth() else {
            throw VoiceCloningError.serverNotRunning
        }

        logger.log("Cloning voice for speaker: \(speakerId)", category: .inference, level: .info)

        let url = ServiceConstants.baseURL.appendingPathComponent("clone")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add audio file
        let audioData = try Data(contentsOf: audioURL)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"reference.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Add speaker_id
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"speaker_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(speakerId)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceCloningError.networkError("Invalid response")
        }

        if httpResponse.statusCode != 200 {
            if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
               let error = errorData["error"] {
                throw VoiceCloningError.cloneFailed(error)
            }
            throw VoiceCloningError.cloneFailed("Status \(httpResponse.statusCode)")
        }

        let cloneResponse = try JSONDecoder().decode(CloneResponse.self, from: data)
        logger.log("Voice cloned successfully: \(cloneResponse.message)", category: .inference, level: .info)

        return cloneResponse
    }

    /// Synthesize speech using Qwen3-TTS voice cloning - unlimited text
    func synthesize(
        text: String,
        speakerId: String,
        language: String = "en",
        speed: Float = 1.0,
        temperature: Float = 0.9,
        topK: Int = 50,
        topP: Float = 1.0,
        repetitionPenalty: Float = 1.05,
        maxTokens: Int = 4096,
        refText: String = ""
    ) async throws -> Data {
        guard await checkHealth() else {
            throw VoiceCloningError.serverNotRunning
        }

        logger.log("Qwen3-TTS synthesizing for speaker: \(speakerId)", category: .inference, level: .info)

        let url = ServiceConstants.baseURL.appendingPathComponent("qwen3/synthesize")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = [
            "text": text,
            "speaker_id": speakerId,
            "language": language,
            "speed": speed,
            "temperature": temperature,
            "top_k": topK,
            "top_p": topP,
            "repetition_penalty": repetitionPenalty,
            "max_tokens": maxTokens,
        ]
        if !refText.isEmpty {
            payload["ref_text"] = refText
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceCloningError.networkError("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200:
            guard data.count > ServiceConstants.wavHeaderMinSize else {
                throw VoiceCloningError.invalidAudio
            }
            logger.log("Qwen3-TTS speech synthesized: \(data.count) bytes", category: .inference, level: .info)
            return data
        case 404:
            throw VoiceCloningError.speakerNotFound(speakerId)
        case 503:
            throw VoiceCloningError.modelNotLoaded
        default:
            if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
               let error = errorData["error"] {
                throw VoiceCloningError.synthesizeFailed(error)
            }
            throw VoiceCloningError.synthesizeFailed("Status \(httpResponse.statusCode)")
        }
    }

    /// List all cloned speakers
    func listSpeakers() async throws -> [SpeakerInfo] {
        guard await checkHealth() else {
            throw VoiceCloningError.serverNotRunning
        }

        let url = ServiceConstants.baseURL.appendingPathComponent("speakers")
        let (data, _) = try await urlSession.data(from: url)
        let response = try JSONDecoder().decode(SpeakersResponse.self, from: data)

        return response.speakers
    }

    /// Delete a cloned speaker
    func deleteSpeaker(_ speakerId: String) async throws {
        guard await checkHealth() else {
            throw VoiceCloningError.serverNotRunning
        }

        let url = ServiceConstants.baseURL.appendingPathComponent("speakers/\(speakerId)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw VoiceCloningError.speakerNotFound(speakerId)
        }

        logger.log("Deleted speaker: \(speakerId)", category: .inference, level: .info)
    }

    /// Rename a cloned speaker
    func renameSpeaker(_ speakerId: String, to newName: String) async throws -> String {
        guard await checkHealth() else {
            throw VoiceCloningError.serverNotRunning
        }

        let url = ServiceConstants.baseURL.appendingPathComponent("speakers/\(speakerId)/rename")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = ["new_name": newName]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceCloningError.networkError("Invalid response")
        }

        if httpResponse.statusCode == 200 {
            if let json = try? JSONDecoder().decode([String: String].self, from: data),
               let resultName = json["new_name"] {
                logger.log("Renamed speaker: \(speakerId) -> \(resultName)", category: .inference, level: .info)
                return resultName
            }
            return newName
        } else if httpResponse.statusCode == 404 {
            throw VoiceCloningError.speakerNotFound(speakerId)
        } else {
            if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
               let error = errorData["error"] {
                throw VoiceCloningError.cloneFailed(error)
            }
            throw VoiceCloningError.cloneFailed("Rename failed")
        }
    }
}
