import Cocoa
import Carbon

class HotkeyManager: @unchecked Sendable {
    var onDoubleTap: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var lastCtrlPressTime: TimeInterval = -999
    private let doubleTapThreshold: TimeInterval = 0.4 // 400ms window for double tap
    private var ctrlIsPressed = false
    private var waitingForSecondTap = false

    func startMonitoring() {
        let eventMask = (1 << CGEventType.flagsChanged.rawValue)

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                manager.handleEvent(event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("Failed to create event tap")
            return
        }

        self.eventTap = eventTap

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func stopMonitoring() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
    }

    private func handleEvent(event: CGEvent) {
        let flags = event.flags
        let ctrlPressed = flags.contains(.maskControl)

        let currentTime = Date().timeIntervalSince1970

        // Detect Ctrl key press (transition from not pressed to pressed)
        if ctrlPressed && !ctrlIsPressed {
            let timeSinceLastPress = currentTime - lastCtrlPressTime

            if waitingForSecondTap && timeSinceLastPress < doubleTapThreshold {
                // Double tap detected - trigger immediately!
                onDoubleTap?()
                waitingForSecondTap = false
                lastCtrlPressTime = -999 // Reset
            } else {
                // First tap - start waiting for second
                waitingForSecondTap = true
                lastCtrlPressTime = currentTime

                // Reset waiting flag after threshold
                DispatchQueue.main.asyncAfter(deadline: .now() + doubleTapThreshold) { [weak self] in
                    self?.waitingForSecondTap = false
                }
            }
        }

        ctrlIsPressed = ctrlPressed
    }
}
