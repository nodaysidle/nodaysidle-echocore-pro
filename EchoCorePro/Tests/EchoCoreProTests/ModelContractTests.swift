import XCTest
@testable import EchoCorePro

final class ModelContractTests: XCTestCase {
    func testSpeechLanguageBackendCodes() {
        let codes = Dictionary(uniqueKeysWithValues: SpeechLanguage.allCases.map { ($0.rawValue, $0.backendCode) })

        XCTAssertEqual(codes["English"], "en")
        XCTAssertEqual(codes["Italian"], "it")
        XCTAssertEqual(codes["German"], "de")
        XCTAssertEqual(codes["Spanish"], "es")
        XCTAssertEqual(codes["French"], "fr")
        XCTAssertEqual(codes["Hindi"], "hi")
        XCTAssertEqual(codes["Dutch"], "nl")
        XCTAssertEqual(codes["Portuguese"], "pt")
        XCTAssertEqual(codes["Arabic"], "ar")
        XCTAssertEqual(codes["Slovenian"], "sl")
    }

    func testOnlySlovenianUsesPiper() {
        for language in SpeechLanguage.allCases {
            XCTAssertEqual(language.usesPiper, language == .slovenian)
        }
    }

    func testVoiceCatalogDecodesBundledVoxtralVoices() throws {
        let json = """
        {
          "voices_by_language": {
            "English": ["casual_female", "casual_male", "cheerful_female", "neutral_female", "neutral_male"],
            "Italian": ["it_female", "it_male"],
            "German": ["de_female", "de_male"],
            "Spanish": ["es_female", "es_male"],
            "French": ["fr_female", "fr_male"],
            "Hindi": ["hi_female", "hi_male"],
            "Dutch": ["nl_female", "nl_male"],
            "Portuguese": ["pt_female", "pt_male"],
            "Arabic": ["ar_male"],
            "Slovenian": ["sl_SI-artur-medium"]
          }
        }
        """.data(using: .utf8)!

        let catalog = try JSONDecoder().decode(VoiceCatalogResponse.self, from: json)

        XCTAssertEqual(catalog.voicesByLanguage["English"]?.count, 5)
        XCTAssertEqual(catalog.voicesByLanguage["German"], ["de_female", "de_male"])
        XCTAssertEqual(catalog.voicesByLanguage["Arabic"], ["ar_male"])
        XCTAssertEqual(catalog.voicesByLanguage["Slovenian"], ["sl_SI-artur-medium"])
    }

    func testBackendHealthDecodesModelReadiness() throws {
        let json = """
        {
          "status": "ready",
          "ready": true,
          "voxtral_loaded": false,
          "stt_ready": true,
          "models_ready": true,
          "models_root": "/Applications/EchoCorePro.app/Contents/Resources/Models",
          "uptime_seconds": 12.5,
          "server_pid": 123,
          "parent_pid": 456
        }
        """.data(using: .utf8)!

        let health = try JSONDecoder().decode(BackendHealth.self, from: json)

        XCTAssertTrue(health.ready)
        XCTAssertTrue(health.sttReady)
        XCTAssertEqual(health.modelsReady, true)
        XCTAssertEqual(health.serverPID, 123)
        XCTAssertEqual(health.parentPID, 456)
    }

    func testBackendHealthDecodesDegradedReadiness() throws {
        let json = """
        {
          "status": "degraded",
          "ready": false,
          "voxtral_loaded": false,
          "stt_ready": false,
          "models_ready": false,
          "models_root": "/Applications/EchoCorePro.app/Contents/Resources/Models",
          "uptime_seconds": 1.0
        }
        """.data(using: .utf8)!

        let health = try JSONDecoder().decode(BackendHealth.self, from: json)

        XCTAssertFalse(health.ready)
        XCTAssertFalse(health.sttReady)
        XCTAssertEqual(health.modelsReady, false)
        XCTAssertEqual(health.status, "degraded")
        XCTAssertEqual(BackendManager.statusMessage(for: health), "Degraded")
    }

    func testBackendSearchPathIncludesCommonMacOSBinaryLocations() {
        let resources = URL(fileURLWithPath: "/Applications/EchoCorePro.app/Contents/Resources")
        let locator = RuntimeLocator(
            resources: resources,
            python: resources.appendingPathComponent("Runtime/venv/bin/python"),
            backend: resources.appendingPathComponent("Runtime/backend.py"),
            models: resources.appendingPathComponent("Models"),
            cache: URL(fileURLWithPath: "/tmp/EchoCorePro"),
            backendLog: URL(fileURLWithPath: "/tmp/EchoCorePro/backend.log")
        )

        let path = locator.backendSearchPath(existing: "/custom/bin:/usr/bin")
        let components = path.split(separator: ":").map(String.init)

        XCTAssertTrue(components.contains("/Applications/EchoCorePro.app/Contents/Resources/Runtime/venv/bin"))
        XCTAssertTrue(components.contains("/Applications/EchoCorePro.app/Contents/Resources/Runtime/bin"))
        XCTAssertTrue(components.contains("/custom/bin"))
        XCTAssertTrue(components.contains("/opt/homebrew/bin"))
        XCTAssertEqual(components.filter { $0 == "/usr/bin" }.count, 1)
    }

    func testMultipartUploadFileContainsAudioPayload() throws {
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("echocore-test-audio-\(UUID().uuidString)")
            .appendingPathExtension("wav")
        let audioPayload = Data([0x52, 0x49, 0x46, 0x46, 0x01, 0x02, 0x03, 0x04])
        try audioPayload.write(to: audioURL)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let multipartURL = try BackendManager.makeMultipartUploadFile(
            audioURL: audioURL,
            boundary: "test-boundary",
            filename: "sample.wav",
            contentType: "audio/wav"
        )
        defer { try? FileManager.default.removeItem(at: multipartURL) }

        let multipart = try Data(contentsOf: multipartURL)
        let body = String(decoding: multipart, as: UTF8.self)

        XCTAssertTrue(body.contains("--test-boundary"))
        XCTAssertTrue(body.contains("filename=\"sample.wav\""))
        XCTAssertTrue(body.contains("Content-Type: audio/wav"))
        XCTAssertTrue(multipart.contains(audioPayload))
        XCTAssertTrue(body.hasSuffix("--test-boundary--\r\n"))
    }

    func testMultipartUploadEscapesProblematicFilenameCharacters() throws {
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("echocore-test-audio-\(UUID().uuidString)")
            .appendingPathExtension("wav")
        try Data([0x52, 0x49, 0x46, 0x46]).write(to: audioURL)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let multipartURL = try BackendManager.makeMultipartUploadFile(
            audioURL: audioURL,
            boundary: "test-boundary",
            filename: "bad\"name\r\n.wav",
            contentType: "audio/wav"
        )
        defer { try? FileManager.default.removeItem(at: multipartURL) }

        let body = String(decoding: try Data(contentsOf: multipartURL), as: UTF8.self)

        XCTAssertTrue(body.contains("filename=\"bad\\\"name.wav\""))
        XCTAssertFalse(body.contains("\r\n.wav\""))
    }
}

private extension Data {
    func contains(_ needle: Data) -> Bool {
        guard !needle.isEmpty, count >= needle.count else {
            return false
        }

        return indices.contains { index in
            let end = index + needle.count
            guard end <= count else {
                return false
            }
            return self[index..<end].elementsEqual(needle)
        }
    }
}
