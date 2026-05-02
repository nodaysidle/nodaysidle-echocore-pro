//
//  BackendManager.swift
//  EchoCorePro
//

import Foundation
import Darwin
import SwiftUI

@MainActor
final class BackendManager: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var statusMessage = "Starting"
    @Published private(set) var health = BackendHealth.offline
    @Published private(set) var activity: [ActivityItem] = []

    private var process: Process?
    private var healthTask: Task<Void, Never>?
    private var backendLogHandle: FileHandle?
    private let baseURL = URL(string: "http://127.0.0.1:8765")!
    private let apiSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 1_200
        configuration.timeoutIntervalForResource = 1_800
        return URLSession(configuration: configuration)
    }()

    deinit {
        process?.terminate()
        healthTask?.cancel()
        try? backendLogHandle?.close()
    }

    func start() async {
        if await probeHealth() {
            if await terminateStaleBackendIfNeeded() {
                try? await Task.sleep(nanoseconds: 800_000_000)
            } else {
                isRunning = true
                statusMessage = "Connected"
                startHealthLoop()
                return
            }
        }

        if await probeHealth() {
            isRunning = true
            statusMessage = "Connected"
            startHealthLoop()
            return
        }

        guard let runtime = RuntimeLocator.locate() else {
            statusMessage = "Runtime not found"
            log("Backend", "Runtime files are missing from the app bundle.")
            return
        }

        let process = Process()
        process.executableURL = runtime.python
        process.arguments = [runtime.backend.path]
        process.currentDirectoryURL = runtime.resources

        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONUNBUFFERED"] = "1"
        environment["PYTHONDONTWRITEBYTECODE"] = "1"
        environment["ECHOCORE_MODEL_ROOT"] = runtime.models.path
        environment["HF_HOME"] = runtime.cache.path
        environment["HF_HUB_CACHE"] = runtime.cache.appendingPathComponent("hub").path
        environment["XDG_CACHE_HOME"] = runtime.cache.appendingPathComponent("xdg").path
        environment["PYTORCH_ENABLE_MPS_FALLBACK"] = "1"
        environment["ECHOCORE_LOG_FILE"] = runtime.backendLog.path
        environment["ECHOCORE_PARENT_PID"] = "\(ProcessInfo.processInfo.processIdentifier)"
        process.environment = environment

        FileManager.default.createFile(atPath: runtime.backendLog.path, contents: nil)
        if let logHandle = try? FileHandle(forWritingTo: runtime.backendLog) {
            _ = try? logHandle.seekToEnd()
            process.standardOutput = logHandle
            process.standardError = logHandle
            backendLogHandle = logHandle
        }

        process.terminationHandler = { [weak self] process in
            Task { @MainActor in
                self?.isRunning = false
                self?.statusMessage = "Backend stopped (\(process.terminationStatus))"
            }
        }

        do {
            try process.run()
            self.process = process
            isRunning = true
            statusMessage = "Loading local models"
            log("Backend", "Started local backend with PID \(process.processIdentifier).")
            startHealthLoop()
        } catch {
            statusMessage = error.localizedDescription
            log("Backend", error.localizedDescription)
        }
    }

    func refreshHealth() async {
        _ = await probeHealth()
    }

    func voices() async throws -> [String: [String]] {
        let data = try await request(path: "voices")
        return try JSONDecoder().decode(VoiceCatalogResponse.self, from: data).voicesByLanguage
    }

    func synthesize(text: String, language: SpeechLanguage, voice: String, speed: Double) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent("tts"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            TTSRequest(text: text, language: language.backendCode, voice: voice, speed: speed)
        )
        request.timeoutInterval = 1_200

        let (data, response) = try await apiSession.data(for: request)
        try validate(response: response, data: data)
        log("TTS", "\(language.rawValue) audio generated with \(voice).")
        return data
    }

    func transcribe(audioURL: URL) async throws -> STTResponse {
        let boundary = UUID().uuidString
        let filename = audioURL.lastPathComponent
        let contentType = mimeType(for: audioURL)
        var request = URLRequest(url: baseURL.appendingPathComponent("stt"))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let uploadFile = try await Task.detached(priority: .userInitiated) {
            try Self.makeMultipartUploadFile(
                audioURL: audioURL,
                boundary: boundary,
                filename: filename,
                contentType: contentType
            )
        }.value
        defer {
            try? FileManager.default.removeItem(at: uploadFile)
        }
        request.timeoutInterval = 1_200

        let (data, response) = try await apiSession.upload(for: request, fromFile: uploadFile)
        try validate(response: response, data: data)
        let result = try JSONDecoder().decode(STTResponse.self, from: data)
        log("STT", "Transcribed \(audioURL.lastPathComponent).")
        return result
    }

    func log(_ title: String, _ detail: String) {
        let item = ActivityItem(title: title, detail: detail)
        activity.insert(item, at: 0)
        activity = Array(activity.prefix(12))
    }

    private func startHealthLoop() {
        healthTask?.cancel()
        healthTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshHealth()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private func probeHealth() async -> Bool {
        do {
            let data = try await request(path: "health", timeout: 1.5)
            health = try JSONDecoder().decode(BackendHealth.self, from: data)
            statusMessage = health.ready ? "Ready" : health.status
            return health.ready
        } catch {
            health = .offline
            return false
        }
    }

    private func terminateStaleBackendIfNeeded() async -> Bool {
        guard let serverPID = health.serverPID else {
            return false
        }

        let currentPID = Int(ProcessInfo.processInfo.processIdentifier)
        guard health.parentPID != currentPID else {
            return false
        }

        kill(pid_t(serverPID), SIGTERM)
        log("Backend", "Stopped stale backend with PID \(serverPID).")
        health = .offline
        isRunning = false
        return true
    }

    private func request(path: String, timeout: TimeInterval = 30) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.timeoutInterval = timeout
        let (data, response) = try await apiSession.data(for: request)
        try validate(response: response, data: data)
        return data
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            if let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = payload["error"] as? String {
                throw BackendError.server(error)
            }
            throw BackendError.server("HTTP \(http.statusCode)")
        }
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "wav": "audio/wav"
        case "mp3": "audio/mpeg"
        case "m4a", "mp4": "audio/mp4"
        case "aif", "aiff": "audio/aiff"
        case "flac": "audio/flac"
        default: "application/octet-stream"
        }
    }

    nonisolated static func makeMultipartUploadFile(
        audioURL: URL,
        boundary: String,
        filename: String,
        contentType: String
    ) throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("echocore-upload-\(UUID().uuidString)")
            .appendingPathExtension("multipart")
        FileManager.default.createFile(atPath: outputURL.path, contents: nil)

        let writer = try FileHandle(forWritingTo: outputURL)
        defer { try? writer.close() }

        let reader = try FileHandle(forReadingFrom: audioURL)
        defer { try? reader.close() }

        writer.write(Data("--\(boundary)\r\n".utf8))
        writer.write(Data("Content-Disposition: form-data; name=\"audio\"; filename=\"\(filename)\"\r\n".utf8))
        writer.write(Data("Content-Type: \(contentType)\r\n\r\n".utf8))

        while true {
            let chunk = try reader.read(upToCount: 1_048_576)
            guard let chunk, !chunk.isEmpty else {
                break
            }
            writer.write(chunk)
        }

        writer.write(Data("\r\n--\(boundary)--\r\n".utf8))
        return outputURL
    }
}

private enum BackendError: LocalizedError {
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Invalid backend response"
        case .server(let message): message
        }
    }
}

private struct RuntimeLocator {
    let resources: URL
    let python: URL
    let backend: URL
    let models: URL
    let cache: URL
    let backendLog: URL

    static func locate() -> RuntimeLocator? {
        let resourceRoot = Bundle.main.resourceURL ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        var candidates = [
            resourceRoot,
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        ]
        #if DEBUG
        candidates.append(URL(fileURLWithPath: "/Volumes/omarchyuser/projekti/nodaysidle-echocore-pro/EchoCorePro"))
        #endif

        for root in candidates {
            let runtime = root.appendingPathComponent("Runtime")
            let python = runtime.appendingPathComponent("venv/bin/python")
            let backend = runtime.appendingPathComponent("backend.py")
            let models = root.appendingPathComponent("Models")
            if FileManager.default.fileExists(atPath: python.path),
               FileManager.default.fileExists(atPath: backend.path) {
                let cache = userCacheDirectory()
                try? FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
                let backendLog = cache.appendingPathComponent("backend.log")
                return RuntimeLocator(resources: root, python: python, backend: backend, models: models, cache: cache, backendLog: backendLog)
            }
        }

        return nil
    }

    private static func userCacheDirectory() -> URL {
        if let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return support
                .appendingPathComponent("EchoCorePro", isDirectory: true)
                .appendingPathComponent("ModelCache", isDirectory: true)
        }
        return URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("EchoCorePro", isDirectory: true)
            .appendingPathComponent("ModelCache", isDirectory: true)
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
