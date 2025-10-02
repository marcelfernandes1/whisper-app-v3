import Cocoa

@MainActor
class RecordingFloatingWindow: NSPanel {
    private var animationView: RecordingAnimationView!

    init() {
        let windowRect = NSRect(x: 0, y: 0, width: 200, height: 80)

        super.init(
            contentRect: windowRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Configure window to float above everything
        self.level = .floating
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Setup animation view
        animationView = RecordingAnimationView(frame: windowRect)
        self.contentView = animationView

        // Position window at top-right of screen
        positionWindow()

        // Start hidden
        self.alphaValue = 0
    }

    private func positionWindow() {
        guard let screen = NSScreen.main else { return }

        let screenRect = screen.visibleFrame
        let windowWidth = frame.width
        let windowHeight = frame.height

        // Position at top-right corner with some padding
        let x = screenRect.maxX - windowWidth - 20
        let y = screenRect.maxY - windowHeight - 20

        setFrameOrigin(NSPoint(x: x, y: y))
    }

    func show() {
        // Make window visible and order front
        self.orderFrontRegardless()

        // Fade in animation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1.0
        })
    }

    func hide() {
        // Fade out animation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0.0
        }, completionHandler: {
            Task { @MainActor in
                self.orderOut(nil)
            }
        })
    }

    func updateAudioLevel(_ level: CGFloat) {
        animationView.updateAudioLevel(level)
    }
}
