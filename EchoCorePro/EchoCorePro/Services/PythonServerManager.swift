//
//  PythonServerManager.swift
//  EchoCorePro
//
//  Manages the lifecycle of the Python TTS server (Qwen3-TTS + Piper)
//

import Combine
import Foundation

/// Manages the Python TTS server subprocess lifecycle
/// Automatically starts the server on app launch and stops it on app termination
@MainActor
final class PythonServerManager: ObservableObject, ServiceProtocol, @unchecked Sendable {

    nonisolated let serviceId = "PythonServerManager"

    // MARK: - Published Properties

    @Published private(set) var isRunning: Bool = false
    @Published private(set) var isHealthy: Bool = false
    @Published private(set) var statusMessage: String = "Not started"

    // MARK: - Private Properties

    private var serverProcess: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private let logger = OSLogManager.shared
    private var healthCheckTimer: Timer?

    // Server configuration
    private let serverPort = 8765
    private let healthCheckInterval: TimeInterval = 5.0
    private let startupTimeout: TimeInterval = 180.0  // Qwen3-TTS + Piper need time to load

    // MARK: - Initialization

    init() {
        logger.log("PythonServerManager created", category: .lifecycle, level: .debug)
    }

    // MARK: - ServiceProtocol

    nonisolated func initialize() async throws {
        await MainActor.run {
            _ = Task {
                await self.startServer()
            }
        }
    }

    nonisolated func shutdown() async {
        await MainActor.run {
            self.stopServer()
        }
    }

    // MARK: - Server Management

    /// Start the Python TTS server
    func startServer() async {
        guard !isRunning else {
            logger.log("Server already running", category: .inference, level: .debug)
            return
        }

        statusMessage = "Checking for existing server..."
        logger.log("Starting Python TTS server", category: .inference, level: .info)

        // Check if a stale server is already running on the port
        if await checkHealth() {
            logger.log("Found existing server on port \(serverPort), killing stale instance...",
                      category: .inference, level: .warning)
            statusMessage = "Killing stale server..."

            // Kill any stale Python TTS server processes
            await killStaleServer()

            // Wait for port to be freed
            try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds

            // Verify it's dead
            if await checkHealth() {
                logger.log("Failed to kill stale server, attempting graceful shutdown via API",
                          category: .inference, level: .warning)
                await requestServerShutdown()
                try? await Task.sleep(nanoseconds: 3_000_000_000)  // 3 seconds
            }
        }

        statusMessage = "Starting server..."

        // Find the Scripts directory
        guard let scriptsPath = findScriptsDirectory() else {
            statusMessage = "Error: Scripts directory not found"
            logger.log("Could not find Scripts directory", category: .inference, level: .error)
            return
        }

        let pythonPath = scriptsPath.appendingPathComponent("venv/bin/python")
        let serverScript = scriptsPath.appendingPathComponent("tts_server.py")

        // Verify files exist
        guard FileManager.default.fileExists(atPath: pythonPath.path) else {
            statusMessage = "Error: Python venv not found"
            logger.log(
                "Python venv not found at: \(pythonPath.path)", category: .inference, level: .error)
            return
        }

        guard FileManager.default.fileExists(atPath: serverScript.path) else {
            statusMessage = "Error: Server script not found"
            logger.log(
                "Server script not found at: \(serverScript.path)", category: .inference,
                level: .error)
            return
        }

        // Create and configure the process
        let process = Process()
        process.executableURL = pythonPath
        process.arguments = [serverScript.path]
        process.currentDirectoryURL = scriptsPath

        // Set up environment
        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONUNBUFFERED"] = "1"
        process.environment = environment

        // Set up pipes for output
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        self.outputPipe = outputPipe
        self.errorPipe = errorPipe

        // Handle process termination
        process.terminationHandler = { [weak self] process in
            Task { @MainActor in
                self?.handleProcessTermination(exitCode: process.terminationStatus)
            }
        }

        // Start the process
        do {
            try process.run()
            serverProcess = process
            isRunning = true
            statusMessage = "Server starting..."

            logger.log(
                "Python server process started (PID: \(process.processIdentifier))",
                category: .inference, level: .info)

            // Monitor output asynchronously
            Task {
                await monitorOutput(pipe: outputPipe, isError: false)
            }
            Task {
                await monitorOutput(pipe: errorPipe, isError: true)
            }

            // Wait for server to become healthy
            await waitForServerHealthy()

            // Start periodic health checks
            startHealthCheckTimer()

        } catch {
            statusMessage = "Error: Failed to start server"
            logger.log(
                "Failed to start Python server: \(error)", category: .inference, level: .error)
        }
    }

    /// Restart the Python server (useful when voice files change)
    func restartServer() async {
        logger.log("Restarting Python TTS server...", category: .inference, level: .info)
        statusMessage = "Restarting server..."

        // Stop existing server
        stopServer()

        // Wait for it to fully stop
        try? await Task.sleep(nanoseconds: 3_000_000_000)  // 3 seconds

        // Kill any lingering processes
        await killStaleServer()
        try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second

        // Reset state
        isRunning = false
        isHealthy = false

        // Start fresh
        await startServer()
    }

    /// Stop the Python server
    func stopServer() {
        guard let process = serverProcess, process.isRunning else {
            logger.log("No server process to stop", category: .inference, level: .debug)
            return
        }

        logger.log(
            "Stopping Python server (PID: \(process.processIdentifier))",
            category: .inference, level: .info)

        // Stop health check timer
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil

        // Send SIGTERM for graceful shutdown
        process.terminate()

        // Give it a moment to shut down gracefully
        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) { [weak self] in
            if process.isRunning {
                // Force kill if still running
                process.interrupt()
            }
            Task { @MainActor in
                self?.serverProcess = nil
                self?.isRunning = false
                self?.isHealthy = false
                self?.statusMessage = "Server stopped"
            }
        }
    }

    // MARK: - Health Check

    /// Check if the server is responding
    func checkHealth() async -> Bool {
        let url = URL(string: "http://127.0.0.1:\(serverPort)/health")!

        do {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 5
            let session = URLSession(configuration: config)

            let (_, response) = try await session.data(from: url)

            if let httpResponse = response as? HTTPURLResponse {
                let healthy = httpResponse.statusCode == 200
                await MainActor.run {
                    self.isHealthy = healthy
                    if healthy {
                        self.statusMessage = "Connected on port \(self.serverPort)"
                    }
                }
                return healthy
            }
        } catch {
            await MainActor.run {
                self.isHealthy = false
            }
        }
        return false
    }

    // MARK: - Private Methods

    /// Find the Scripts directory relative to the app bundle or source
    private func findScriptsDirectory() -> URL? {
        let fm = FileManager.default

        // List of candidate paths to check
        var candidates: [(String, URL)] = []

        // 1. Try app bundle resources first (if Scripts is copied into .app)
        if let bundlePath = Bundle.main.resourcePath {
            let scriptsInBundle = URL(fileURLWithPath: bundlePath).appendingPathComponent("Scripts")
            candidates.append(("Bundle Resources", scriptsInBundle))
        }

        // 2. Try relative to the .app location (Scripts as sibling to .app)
        let bundleURL = Bundle.main.bundleURL
        let appParentDir = bundleURL.deletingLastPathComponent()
        let scriptsNextToApp = appParentDir.appendingPathComponent("Scripts")
        candidates.append(("Next to .app", scriptsNextToApp))

        // 3. Try going up one more level (in case app is in a subdirectory)
        let scriptsUpOneLevel = appParentDir.deletingLastPathComponent().appendingPathComponent(
            "Scripts")
        candidates.append(("Parent of .app parent", scriptsUpOneLevel))

        // 4. Fixed development path
        let fixedDevPath = URL(
            fileURLWithPath:
                "/Volumes/omarchyuser/projekti/nodaysidle-echocore-pro/EchoCorePro/Scripts")
        candidates.append(("Fixed dev path", fixedDevPath))

        // 5. User's Application Support directory (primary location for installed app)
        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            // Check EchoCorePro directly (flat structure)
            let appSupportDirect = appSupport.appendingPathComponent("EchoCorePro")
            candidates.append(("Application Support (direct)", appSupportDirect))

            // Also check nested Scripts subfolder (legacy)
            let appSupportScripts = appSupport.appendingPathComponent("EchoCorePro/Scripts")
            candidates.append(("Application Support (Scripts)", appSupportScripts))
        }

        // 6. Scripts next to /Applications/EchoCorePro.app (for development)
        let applicationsScripts = URL(fileURLWithPath: "/Applications/EchoCorePro/Scripts")
        candidates.append(("Applications folder", applicationsScripts))

        // 7. Current working directory
        let cwdScripts = URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent(
            "Scripts")
        candidates.append(("Current working dir", cwdScripts))

        // Log all candidates for debugging
        logger.log(
            "Looking for Scripts directory. Bundle URL: \(bundleURL.path)", category: .inference,
            level: .debug)

        for (name, url) in candidates {
            let exists = fm.fileExists(atPath: url.path)
            let pythonExists = fm.fileExists(
                atPath: url.appendingPathComponent("venv/bin/python").path)
            logger.log(
                "  \(name): \(url.path) - exists: \(exists), python: \(pythonExists)",
                category: .inference, level: .debug)

            if exists && pythonExists {
                logger.log(
                    "Found Scripts directory at: \(url.path)", category: .inference, level: .info)
                return url
            }
        }

        logger.log(
            "Could not find Scripts directory with Python venv!", category: .inference,
            level: .error)
        return nil
    }

    /// Wait for the server to become healthy
    private func waitForServerHealthy() async {
        let startTime = Date()
        var attempts = 0

        while Date().timeIntervalSince(startTime) < startupTimeout {
            attempts += 1

            if await checkHealth() {
                logger.log(
                    "Server became healthy after \(attempts) attempts",
                    category: .inference, level: .info)
                return
            }

            // Wait before next check (longer initially as models load)
            let delay = min(Double(attempts) * 0.5, 3.0)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            await MainActor.run {
                self.statusMessage = "Loading models... (\(attempts))"
            }
        }

        await MainActor.run {
            self.statusMessage = "Server started (health check pending)"
        }
        logger.log(
            "Server health check timed out after \(startupTimeout)s",
            category: .inference, level: .warning)
    }

    /// Start periodic health check timer
    private func startHealthCheckTimer() {
        healthCheckTimer = Timer.scheduledTimer(
            withTimeInterval: healthCheckInterval, repeats: true
        ) { [weak self] _ in
            Task {
                await self?.checkHealth()
            }
        }
    }

    /// Handle process termination
    private func handleProcessTermination(exitCode: Int32) {
        logger.log(
            "Python server terminated with exit code: \(exitCode)",
            category: .inference, level: exitCode == 0 ? .info : .warning)

        isRunning = false
        isHealthy = false
        statusMessage = exitCode == 0 ? "Server stopped" : "Server crashed (exit: \(exitCode))"

        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }

    /// Kill any stale Python TTS server processes
    private func killStaleServer() async {
        logger.log("Killing stale TTS server processes...", category: .inference, level: .info)

        // Use pkill to find and kill Python processes running tts_server
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        task.arguments = ["-f", "python.*tts_server"]

        do {
            try task.run()
            task.waitUntilExit()
            logger.log("pkill completed with exit code: \(task.terminationStatus)",
                      category: .inference, level: .debug)
        } catch {
            logger.log("pkill failed: \(error)", category: .inference, level: .warning)
        }

        // Also try to kill by port using lsof + kill
        let lsofTask = Process()
        lsofTask.executableURL = URL(fileURLWithPath: "/bin/sh")
        lsofTask.arguments = ["-c", "lsof -ti :\(serverPort) | xargs kill -9 2>/dev/null || true"]

        do {
            try lsofTask.run()
            lsofTask.waitUntilExit()
        } catch {
            logger.log("Port kill failed: \(error)", category: .inference, level: .debug)
        }
    }

    /// Request graceful shutdown via API
    private func requestServerShutdown() async {
        let url = URL(string: "http://127.0.0.1:\(serverPort)/shutdown")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 5

        do {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 5
            let session = URLSession(configuration: config)
            _ = try await session.data(for: request)
            logger.log("Shutdown request sent to stale server", category: .inference, level: .info)
        } catch {
            logger.log("Shutdown request failed: \(error)", category: .inference, level: .debug)
        }
    }

    /// Monitor process output
    private func monitorOutput(pipe: Pipe, isError: Bool) async {
        let handle = pipe.fileHandleForReading

        handle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let output = String(data: data, encoding: .utf8) else { return }

            let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
            for line in lines {
                Task { @MainActor in
                    self?.logger.log(
                        "[Python] \(line)",
                        category: .inference,
                        level: isError ? .warning : .debug
                    )
                }
            }
        }
    }
}
