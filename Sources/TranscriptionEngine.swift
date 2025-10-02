import Foundation

class TranscriptionEngine: @unchecked Sendable {
    private let modelName = "medium" // Options: tiny, base, small, medium, large
    private var language: String {
        get {
            return UserDefaults.standard.string(forKey: "transcriptionLanguage") ?? "auto"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "transcriptionLanguage")
        }
    }

    func setLanguage(_ lang: String) {
        language = lang
    }

    func transcribe(audioURL: URL, completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            print("🎤 Starting transcription...")
            print("📁 Audio file: \(audioURL.path)")

            // Find the project directory (where transcribe.py is located)
            let projectPath = self.findProjectPath()

            guard let projectPath = projectPath else {
                print("❌ Error: Could not find project directory")
                print("   Searched from: \(Bundle.main.executablePath ?? "unknown")")
                print("   Current dir: \(FileManager.default.currentDirectoryPath)")
                completion(nil)
                return
            }

            print("✅ Project path: \(projectPath.path)")

            let pythonScript = projectPath.appendingPathComponent("transcribe.py").path
            let pythonExecutable = projectPath.appendingPathComponent("venv/bin/python3").path
            let audioPath = audioURL.path

            // Check if venv exists, otherwise use system Python
            let python = FileManager.default.fileExists(atPath: pythonExecutable) ? pythonExecutable : "/usr/bin/env python3"

            print("🐍 Python: \(python)")
            print("📝 Script: \(pythonScript)")
            print("🔊 Audio: \(audioPath)")
            print("🧠 Model: \(self.modelName)")
            print("🌍 Language: \(self.language)")

            // Create process to run Python script
            let process = Process()
            process.executableURL = URL(fileURLWithPath: python)
            process.arguments = [pythonScript, audioPath, self.modelName, self.language]

            let pipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = pipe
            process.standardError = errorPipe

            do {
                print("▶️ Running transcription...")
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                let output = String(data: data, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

                print("📤 Exit code: \(process.terminationStatus)")
                if !output.isEmpty {
                    print("📤 Output: \(output)")
                }
                if !errorOutput.isEmpty {
                    print("⚠️ Stderr: \(errorOutput)")
                }

                if process.terminationStatus == 0 {
                    let transcription = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !transcription.isEmpty {
                        print("✅ Transcription successful: \"\(transcription)\"")
                        completion(transcription)
                    } else {
                        print("❌ Empty transcription")
                        completion(nil)
                    }
                } else {
                    print("❌ Transcription failed with exit code \(process.terminationStatus)")
                    completion(nil)
                }
            } catch {
                print("❌ Failed to run transcription: \(error)")
                completion(nil)
            }
        }
    }

    private func findProjectPath() -> URL? {
        // Try to find the project directory by looking for transcribe.py
        // Start from the executable location and go up

        if let executablePath = Bundle.main.executablePath {
            var currentPath = URL(fileURLWithPath: executablePath).deletingLastPathComponent()

            // Check up to 5 levels up
            for _ in 0..<5 {
                let scriptPath = currentPath.appendingPathComponent("transcribe.py")
                if FileManager.default.fileExists(atPath: scriptPath.path) {
                    return currentPath
                }
                currentPath = currentPath.deletingLastPathComponent()
            }
        }

        // Fallback: check current directory
        let currentDir = FileManager.default.currentDirectoryPath
        let scriptPath = URL(fileURLWithPath: currentDir).appendingPathComponent("transcribe.py")
        if FileManager.default.fileExists(atPath: scriptPath.path) {
            return URL(fileURLWithPath: currentDir)
        }

        return nil
    }
}
