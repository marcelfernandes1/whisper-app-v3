import Foundation
import AVFoundation
import CoreAudio

@MainActor
class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var selectedDeviceID: String?
    private var levelTimer: Timer?
    var onAudioLevelUpdate: ((CGFloat) -> Void)?

    override init() {
        super.init()
        // Pre-initialize the audio recorder to eliminate startup delay
        prepareNextRecorder()
    }

    struct MicrophoneDevice {
        let id: String
        let name: String
    }

    func getAvailableMicrophones() -> [MicrophoneDevice] {
        var devices: [MicrophoneDevice] = []

        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone, .externalUnknown],
            mediaType: .audio,
            position: .unspecified
        )

        for device in discoverySession.devices {
            devices.append(MicrophoneDevice(id: device.uniqueID, name: device.localizedName))
        }

        return devices
    }

    func setMicrophone(deviceID: String?) {
        selectedDeviceID = deviceID
        if let deviceID = deviceID {
            UserDefaults.standard.set(deviceID, forKey: "selectedMicrophoneID")
        } else {
            UserDefaults.standard.removeObject(forKey: "selectedMicrophoneID")
        }
    }

    func getSelectedMicrophoneID() -> String? {
        if let deviceID = selectedDeviceID {
            return deviceID
        }
        return UserDefaults.standard.string(forKey: "selectedMicrophoneID")
    }

    func startRecording(completion: @escaping (Bool) -> Void) {
        // Use the pre-initialized recorder for instant start
        guard let recorder = audioRecorder else {
            // Fallback: prepare a new recorder if somehow it's nil
            prepareNextRecorder()
            guard let recorder = audioRecorder else {
                completion(false)
                return
            }
            recorder.record()
            startLevelMonitoring()
            completion(true)
            return
        }

        // Start recording immediately with the prepared recorder
        recorder.record()
        startLevelMonitoring()
        completion(true)
    }

    private func setDefaultInputDevice(deviceID: String) {
        // Get all audio devices
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        guard status == kAudioHardwareNoError else { return }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var audioDevices = [AudioDeviceID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &audioDevices
        )

        guard status == kAudioHardwareNoError else { return }

        // Find the device with matching UID
        for deviceId in audioDevices {
            var uidPropertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            var uid: CFString = "" as CFString
            var uidSize = UInt32(MemoryLayout<CFString>.size)

            status = AudioObjectGetPropertyData(
                deviceId,
                &uidPropertyAddress,
                0,
                nil,
                &uidSize,
                &uid
            )

            if status == kAudioHardwareNoError && (uid as String) == deviceID {
                // Set as default input device
                var defaultDevicePropertyAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioHardwarePropertyDefaultInputDevice,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                )

                var deviceToSet = deviceId
                let setSize = UInt32(MemoryLayout<AudioDeviceID>.size)

                AudioObjectSetPropertyData(
                    AudioObjectID(kAudioObjectSystemObject),
                    &defaultDevicePropertyAddress,
                    0,
                    nil,
                    setSize,
                    &deviceToSet
                )
                break
            }
        }
    }

    func stopRecording(completion: @escaping (URL?) -> Void) {
        stopLevelMonitoring()
        audioRecorder?.stop()
        let url = recordingURL

        // Prepare the next recorder immediately after stopping
        prepareNextRecorder()

        completion(url)
    }

    private func prepareNextRecorder() {
        do {
            // Set the preferred input device if a microphone is selected
            if let deviceID = getSelectedMicrophoneID(),
               AVCaptureDevice(uniqueID: deviceID) != nil {
                setDefaultInputDevice(deviceID: deviceID)
            }

            // Create temporary file for next recording
            let tempDir = FileManager.default.temporaryDirectory
            recordingURL = tempDir.appendingPathComponent(UUID().uuidString + ".wav")

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 16000.0,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false
            ]

            guard let url = recordingURL else { return }

            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true // Enable audio level metering
            audioRecorder?.prepareToRecord() // Pre-initialize audio system
        } catch {
            print("Failed to prepare recorder: \(error)")
        }
    }

    private func startLevelMonitoring() {
        // Poll audio levels every 0.05 seconds (20 times per second)
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAudioLevel()
            }
        }
    }

    private func stopLevelMonitoring() {
        levelTimer?.invalidate()
        levelTimer = nil
    }

    private func updateAudioLevel() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }

        recorder.updateMeters()

        // Get average power for channel 0 (mono recording)
        // Returns value in decibels (typically -160 to 0)
        let averagePower = recorder.averagePower(forChannel: 0)

        // Normalize to 0.0 - 1.0 range
        // -50 dB is roughly silence, 0 dB is max
        let normalized = max(0.0, min(1.0, (averagePower + 50) / 50))

        // Call the callback with the normalized level
        onAudioLevelUpdate?(CGFloat(normalized))
    }
}
