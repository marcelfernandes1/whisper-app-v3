import Cocoa
import AVFoundation

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotkeyManager: HotkeyManager!
    private var audioRecorder: AudioRecorder!
    private var transcriptionEngine: TranscriptionEngine!
    private var textInserter: TextInserter!
    private var floatingWindow: RecordingFloatingWindow!
    private var toggleMenuItem: NSMenuItem!

    private var isRecording = false
    private var currentAudioURL: URL?  // Store audio for retry capability
    private var recordingStartTime: Date?
    private var recordingTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Whisper Transcribe")
            button.image?.isTemplate = true
        }

        // Initialize components
        hotkeyManager = HotkeyManager()
        audioRecorder = AudioRecorder()
        transcriptionEngine = TranscriptionEngine()
        textInserter = TextInserter()
        floatingWindow = RecordingFloatingWindow()

        setupMenu()

        // Set up audio level callback for floating window animation
        audioRecorder.onAudioLevelUpdate = { [weak self] level in
            self?.floatingWindow.updateAudioLevel(level)
        }

        // Set up hotkey callback
        hotkeyManager.onDoubleTap = { [weak self] in
            DispatchQueue.main.async {
                self?.toggleRecording()
            }
        }

        // Request permissions
        requestPermissions()

        // Start monitoring hotkeys
        hotkeyManager.startMonitoring()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.stopMonitoring()
        transcriptionEngine.shutdown()
    }

    private func setupMenu() {
        let menu = NSMenu()

        // Add toggle recording menu item
        toggleMenuItem = NSMenuItem(title: "Start Recording", action: #selector(menuToggleRecording), keyEquivalent: "r")
        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Status: Ready", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        // Model submenu
        let modelItem = NSMenuItem(title: "Model", action: nil, keyEquivalent: "")
        let modelSubmenu = NSMenu()

        let models: [(name: String, code: String)] = [
            ("Fastest", "base"),
            ("Faster", "small"),
            ("Most Accurate", "medium")
        ]

        for model in models {
            let item = NSMenuItem(title: model.name, action: #selector(selectModel(_:)), keyEquivalent: "")
            item.representedObject = model.code
            item.target = self
            modelSubmenu.addItem(item)
        }

        modelItem.submenu = modelSubmenu
        menu.addItem(modelItem)

        // Language submenu
        let languageItem = NSMenuItem(title: "Language", action: nil, keyEquivalent: "")
        let languageSubmenu = NSMenu()

        let languages: [(name: String, code: String)] = [
            ("Auto-detect", "auto"),
            ("Portuguese (Brazil)", "pt"),
            ("English", "en"),
            ("Spanish", "es"),
            ("French", "fr"),
            ("German", "de"),
            ("Italian", "it"),
            ("Japanese", "ja")
        ]

        for language in languages {
            let item = NSMenuItem(title: language.name, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.representedObject = language.code
            item.target = self
            languageSubmenu.addItem(item)
        }

        languageItem.submenu = languageSubmenu
        menu.addItem(languageItem)

        // Microphone submenu
        let microphoneItem = NSMenuItem(title: "Microphone", action: nil, keyEquivalent: "")
        let microphoneSubmenu = NSMenu()

        // Add auto-detect option
        let autoItem = NSMenuItem(title: "Auto-detect (System)", action: #selector(selectMicrophone(_:)), keyEquivalent: "")
        autoItem.representedObject = nil
        autoItem.target = self
        microphoneSubmenu.addItem(autoItem)

        microphoneSubmenu.addItem(NSMenuItem.separator())

        // Add available microphones
        let microphones = audioRecorder.getAvailableMicrophones()
        for microphone in microphones {
            let item = NSMenuItem(title: microphone.name, action: #selector(selectMicrophone(_:)), keyEquivalent: "")
            item.representedObject = microphone.id
            item.target = self
            microphoneSubmenu.addItem(item)
        }

        microphoneItem.submenu = microphoneSubmenu
        menu.addItem(microphoneItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
        updateModelMenu()
        updateLanguageMenu()
        updateMicrophoneMenu()
    }

    private func updateStatus(_ status: String) {
        DispatchQueue.main.async {
            if let menu = self.statusItem.menu {
                menu.items[0].title = "Status: \(status)"
            }
        }
    }

    private func updateIcon(recording: Bool) {
        DispatchQueue.main.async {
            if let button = self.statusItem.button {
                let iconName = recording ? "mic.circle.fill" : "mic.fill"
                button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Whisper Transcribe")
                button.image?.isTemplate = true
            }
        }
    }

    private func toggleRecording() {
        if isRecording {
            stopRecordingAndTranscribe()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        print("🎙️ Starting recording NOW")

        // Update UI immediately
        isRecording = true
        updateStatus("Recording...")
        updateIcon(recording: true)
        toggleMenuItem.title = "Stop Recording"

        // Show floating animation window
        floatingWindow.show()

        // Start recording timer
        recordingStartTime = Date()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let startTime = self.recordingStartTime else { return }
                let elapsed = Date().timeIntervalSince(startTime)
                self.floatingWindow.updateDuration(elapsed)
            }
        }

        // Start audio recording
        audioRecorder.startRecording { success in
            if !success {
                Task { @MainActor in
                    self.recordingTimer?.invalidate()
                    self.recordingTimer = nil
                    self.recordingStartTime = nil
                    self.updateStatus("Error: Failed to start recording")
                    self.updateIcon(recording: false)
                    self.isRecording = false
                    self.floatingWindow.hide()
                }
            } else {
                print("✅ Audio recording started")
            }
        }
    }

    private func stopRecordingAndTranscribe() {
        // Stop recording timer
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartTime = nil

        updateStatus("Transcribing...")
        updateIcon(recording: false)
        isRecording = false
        toggleMenuItem.title = "Start Recording"

        // Show processing state (don't hide window)
        floatingWindow.showProcessing()

        audioRecorder.stopRecording { audioFileURL in
            guard let audioURL = audioFileURL else {
                DispatchQueue.main.async {
                    self.updateStatus("Error: No audio recorded")
                    self.floatingWindow.showError(
                        message: "No audio was recorded",
                        onRetry: {
                            self.floatingWindow.hide()
                        },
                        onCancel: {
                            self.floatingWindow.hide()
                        }
                    )
                }
                return
            }

            // Save audio URL for potential retry
            self.currentAudioURL = audioURL

            // Transcribe audio
            self.performTranscription(audioURL: audioURL)
        }
    }

    private func performTranscription(audioURL: URL) {
        transcriptionEngine.transcribe(audioURL: audioURL) { transcription in
            DispatchQueue.main.async {
                if let text = transcription {
                    // Success: Insert text and hide window
                    self.updateStatus("Pasting text...")
                    self.textInserter.insertText(text)
                    self.updateStatus("Ready")
                    self.floatingWindow.hide()

                    // Clean up audio file
                    self.cleanupAudioFile()
                } else {
                    // Error: Show error state with retry option
                    self.updateStatus("Error: Transcription failed")
                    self.floatingWindow.showError(
                        message: "Transcription failed. Check your connection and try again.",
                        onRetry: {
                            self.retryTranscription()
                        },
                        onCancel: {
                            self.cancelTranscription()
                        }
                    )
                }
            }
        }
    }

    private func retryTranscription() {
        guard let audioURL = currentAudioURL else {
            floatingWindow.hide()
            updateStatus("Error: Audio file not found")
            return
        }

        updateStatus("Retrying transcription...")
        floatingWindow.showProcessing()
        performTranscription(audioURL: audioURL)
    }

    private func cancelTranscription() {
        cleanupAudioFile()
        floatingWindow.hide()
        updateStatus("Ready")
    }

    private func cleanupAudioFile() {
        if let audioURL = currentAudioURL {
            try? FileManager.default.removeItem(at: audioURL)
            currentAudioURL = nil
        }
    }

    private func requestPermissions() {
        // Request microphone permission
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if !granted {
                DispatchQueue.main.async {
                    self.showAlert(message: "Microphone access is required for recording.")
                }
            }
        }

        // Check accessibility permission
        if !AXIsProcessTrusted() {
            DispatchQueue.main.async {
                self.showAccessibilityAlert()
            }
        }
    }

    private func showAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "Permission Required"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "This app needs accessibility permissions to paste text into other applications. Please enable it in System Preferences > Security & Privacy > Accessibility."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }

    @objc private func selectModel(_ sender: NSMenuItem) {
        guard let modelCode = sender.representedObject as? String else { return }
        transcriptionEngine.setModel(modelCode)
        updateModelMenu()
        updateStatus("Model set to \(sender.title)")

        // Reset status after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.updateStatus("Ready")
        }
    }

    private func updateModelMenu() {
        let currentModel = UserDefaults.standard.string(forKey: "transcriptionModel") ?? "small"

        if let menu = statusItem.menu,
           let modelItem = menu.items.first(where: { $0.title == "Model" }),
           let modelSubmenu = modelItem.submenu {
            for item in modelSubmenu.items {
                if let code = item.representedObject as? String {
                    item.state = (code == currentModel) ? .on : .off
                }
            }
        }
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let languageCode = sender.representedObject as? String else { return }
        transcriptionEngine.setLanguage(languageCode)
        updateLanguageMenu()
        updateStatus("Language set to \(sender.title)")

        // Reset status after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.updateStatus("Ready")
        }
    }

    private func updateLanguageMenu() {
        let currentLanguage = UserDefaults.standard.string(forKey: "transcriptionLanguage") ?? "auto"

        if let menu = statusItem.menu,
           let languageItem = menu.items.first(where: { $0.title == "Language" }),
           let languageSubmenu = languageItem.submenu {
            for item in languageSubmenu.items {
                if let code = item.representedObject as? String {
                    item.state = (code == currentLanguage) ? .on : .off
                }
            }
        }
    }

    @objc private func selectMicrophone(_ sender: NSMenuItem) {
        let deviceID = sender.representedObject as? String
        audioRecorder.setMicrophone(deviceID: deviceID)
        updateMicrophoneMenu()

        let micName = deviceID == nil ? "Auto-detect (System)" : sender.title
        updateStatus("Microphone set to \(micName)")

        // Reset status after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.updateStatus("Ready")
        }
    }

    private func updateMicrophoneMenu() {
        let currentMicID = audioRecorder.getSelectedMicrophoneID()

        if let menu = statusItem.menu,
           let microphoneItem = menu.items.first(where: { $0.title == "Microphone" }),
           let microphoneSubmenu = microphoneItem.submenu {
            for item in microphoneSubmenu.items {
                // Check if this is the auto-detect item (representedObject is nil)
                if item.representedObject == nil && item.action != nil {
                    item.state = (currentMicID == nil) ? .on : .off
                } else if let deviceID = item.representedObject as? String {
                    item.state = (deviceID == currentMicID) ? .on : .off
                }
            }
        }
    }

    @objc private func menuToggleRecording() {
        toggleRecording()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
