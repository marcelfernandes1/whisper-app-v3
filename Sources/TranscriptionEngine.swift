import Foundation

class TranscriptionEngine: @unchecked Sendable {
    private var modelName: String {
        get {
            return UserDefaults.standard.string(forKey: "transcriptionModel") ?? "small"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "transcriptionModel")
        }
    }

    private var language: String {
        get {
            return UserDefaults.standard.string(forKey: "transcriptionLanguage") ?? "auto"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "transcriptionLanguage")
        }
    }

    // Daemon process management
    private var daemonProcess: Process?
    private var daemonInput: FileHandle?
    private var daemonOutput: FileHandle?
    private var daemonError: FileHandle?
    private let daemonQueue = DispatchQueue(label: "com.whispertranscribe.daemon")
    private var isInitialized = false
    private let initLock = NSLock()

    init() {
        // Start daemon asynchronously
        startDaemon()
    }

    deinit {
        shutdown()
    }

    func setLanguage(_ lang: String) {
        language = lang
    }

    func setModel(_ model: String) {
        modelName = model
    }

    private func startDaemon() {
        daemonQueue.async {
            self.initLock.lock()
            defer { self.initLock.unlock() }

            guard !self.isInitialized else {
                print("ℹ️  Daemon already initialized, skipping")
                return
            }

            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("🚀 STARTING TRANSCRIPTION DAEMON")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            // Find the bundled daemon executable in the app's Resources folder
            guard let resourcePath = Bundle.main.resourcePath else {
                print("❌ Error: Could not find app resources")
                return
            }

            let daemonPath = URL(fileURLWithPath: resourcePath).appendingPathComponent("transcribe_daemon").path

            // Check if bundled daemon exists
            guard FileManager.default.fileExists(atPath: daemonPath) else {
                print("❌ Error: Bundled daemon not found at: \(daemonPath)")
                print("   (The app may not be properly packaged)")
                return
            }

            print("📍 Resource path: \(resourcePath)")
            print("🤖 Daemon: \(daemonPath)")
            print("🧠 Model: \(self.modelName)")

            // Create daemon process - directly execute the bundled daemon
            let process = Process()
            process.executableURL = URL(fileURLWithPath: daemonPath)
            process.arguments = []

            let inputPipe = Pipe()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.standardInput = inputPipe
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                print("▶️  Launching daemon process...")
                try process.run()

                self.daemonProcess = process
                self.daemonInput = inputPipe.fileHandleForWriting
                self.daemonOutput = outputPipe.fileHandleForReading
                self.daemonError = errorPipe.fileHandleForReading

                // Monitor stderr for daemon status messages
                self.monitorDaemonStderr()

                self.isInitialized = true
                print("✅ Daemon process started (PID: \(process.processIdentifier))")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

                // Preload all three models immediately
                self.preloadAllModels()

            } catch {
                print("❌ Failed to start daemon: \(error)")
            }
        }
    }

    private func monitorDaemonStderr() {
        // Read stderr asynchronously for status messages
        daemonError?.readabilityHandler = { handle in
            let data = handle.availableData
            if data.count > 0, let message = String(data: data, encoding: .utf8) {
                print("📋 Daemon: \(message.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }
    }

    private func preloadAllModels() {
        print("\n🔄 Preloading all Whisper models (base, small, medium)...")

        let modelsToPreload = ["base", "small", "medium"]

        for model in modelsToPreload {
            preloadModel(model)
        }

        print("✅ All models preloaded and cached\n")
    }

    private func preloadModel(_ modelName: String) {
        print("🔄 Preloading '\(modelName)' model...")

        let request: [String: Any] = [
            "action": "load_model",
            "model": modelName
        ]

        guard let requestData = try? JSONSerialization.data(withJSONObject: request),
              var requestString = String(data: requestData, encoding: .utf8) else {
            print("❌ Failed to create preload request for \(modelName)")
            return
        }

        requestString += "\n"

        guard let inputHandle = daemonInput else {
            print("❌ Daemon input not available for preload")
            return
        }

        inputHandle.write(requestString.data(using: .utf8)!)

        // Read response (blocking, to ensure model is loaded before continuing)
        guard let outputHandle = daemonOutput else {
            return
        }

        var responseData = Data()
        let deadline = Date().addingTimeInterval(30.0) // 30 second timeout for model loading

        while Date() < deadline {
            let chunk = outputHandle.availableData
            if chunk.isEmpty {
                Thread.sleep(forTimeInterval: 0.1)
                continue
            }

            responseData.append(chunk)

            // Check if we have a complete line
            if let str = String(data: responseData, encoding: .utf8), str.contains("\n") {
                break
            }
        }

        if let responseString = String(data: responseData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           let responseJson = try? JSONSerialization.jsonObject(with: responseString.data(using: .utf8)!) as? [String: Any],
           let status = responseJson["status"] as? String, status == "success" {
            print("✅ Model '\(modelName)' preloaded successfully")
        } else {
            print("⚠️  Model '\(modelName)' preload response not received (will load on first use)")
        }
    }

    private func waitForDaemonReady(timeout: TimeInterval = 10.0) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while !isInitialized && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
        }

        return isInitialized
    }

    func transcribe(audioURL: URL, completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let startTime = Date()

            print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("🎤 TRANSCRIPTION REQUEST")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("📁 Audio file: \(audioURL.path)")
            print("🧠 Model: \(self.modelName)")
            print("🌍 Language: \(self.language)")

            // Ensure daemon is ready
            if !self.isInitialized {
                print("⏳ Waiting for daemon to initialize...")
                guard self.waitForDaemonReady() else {
                    print("❌ Daemon failed to initialize")
                    completion(nil)
                    return
                }
                print("✅ Daemon is ready!")
            } else {
                print("✅ Daemon is already running")
            }

            // Verify daemon is still running
            if self.daemonProcess == nil || !self.daemonProcess!.isRunning {
                print("❌ Daemon is not running, attempting restart...")
                self.isInitialized = false
                self.startDaemon()

                guard self.waitForDaemonReady() else {
                    print("❌ Failed to restart daemon")
                    completion(nil)
                    return
                }
                print("✅ Daemon restarted successfully")
            }

            // Send transcription request to daemon
            let request: [String: Any] = [
                "action": "transcribe",
                "audio_path": audioURL.path,
                "model": self.modelName,
                "language": self.language
            ]

            guard let requestData = try? JSONSerialization.data(withJSONObject: request),
                  var requestString = String(data: requestData, encoding: .utf8) else {
                print("❌ Failed to create request")
                completion(nil)
                return
            }

            requestString += "\n"

            print("📤 Sending request to daemon...")

            // Send request
            guard let inputHandle = self.daemonInput else {
                print("❌ Daemon input not available")
                completion(nil)
                return
            }

            let sendTime = Date()
            inputHandle.write(requestString.data(using: .utf8)!)
            print("✉️  Request sent (\(String(format: "%.3f", Date().timeIntervalSince(sendTime)))s)")

            // Read response (blocking read until newline)
            guard let outputHandle = self.daemonOutput else {
                print("❌ Daemon output not available")
                completion(nil)
                return
            }

            print("⏳ Waiting for response from daemon...")

            // Read until newline
            var responseData = Data()
            let readStartTime = Date()
            while true {
                let chunk = outputHandle.availableData
                if chunk.isEmpty {
                    Thread.sleep(forTimeInterval: 0.01)
                    continue
                }

                responseData.append(chunk)

                // Check if we have a complete line
                if let str = String(data: responseData, encoding: .utf8), str.contains("\n") {
                    break
                }
            }

            let readTime = Date().timeIntervalSince(readStartTime)
            print("📥 Response received (\(String(format: "%.2f", readTime))s)")

            guard let responseString = String(data: responseData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let responseJson = try? JSONSerialization.jsonObject(with: responseString.data(using: .utf8)!) as? [String: Any] else {
                print("❌ Failed to parse daemon response")
                completion(nil)
                return
            }

            let totalTime = Date().timeIntervalSince(startTime)

            if let status = responseJson["status"] as? String, status == "success",
               let text = responseJson["text"] as? String {
                print("✅ Transcription successful!")
                print("📝 Result: \"\(text)\"")
                print("⏱️  Total time: \(String(format: "%.2f", totalTime))s")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
                completion(text)
            } else if let message = responseJson["message"] as? String {
                print("❌ Daemon error: \(message)")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
                completion(nil)
            } else {
                print("❌ Unknown response format")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
                completion(nil)
            }
        }
    }

    func shutdown() {
        initLock.lock()
        defer { initLock.unlock() }

        guard isInitialized else {
            print("ℹ️  Daemon not initialized, nothing to shutdown")
            return
        }

        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🛑 SHUTTING DOWN DAEMON")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // Send shutdown command
        print("📤 Sending shutdown request to daemon...")
        let shutdownRequest = "{\"action\": \"shutdown\"}\n"
        try? daemonInput?.write(contentsOf: shutdownRequest.data(using: .utf8)!)

        // Give daemon time to shut down gracefully
        print("⏳ Waiting for graceful shutdown...")
        Thread.sleep(forTimeInterval: 0.5)

        // Terminate if still running
        if let process = daemonProcess, process.isRunning {
            print("⚠️  Daemon still running, terminating process...")
            process.terminate()
        }

        daemonInput = nil
        daemonOutput = nil
        daemonError = nil
        daemonProcess = nil
        isInitialized = false

        print("✅ Daemon shut down successfully")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }

}
