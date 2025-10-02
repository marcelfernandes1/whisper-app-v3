import Cocoa

@MainActor
class RecordingFloatingWindow: NSPanel {
    private var liquidGlassView: LiquidGlassView!

    init() {
        // Window size for Liquid Glass floating indicator
        let windowRect = NSRect(x: 0, y: 0, width: 200, height: 100)

        super.init(
            contentRect: windowRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Configure window to float above everything
        self.level = .floating
        self.backgroundColor = .clear  // Clear background - glass provides the look
        self.isOpaque = false
        self.hasShadow = false  // NSGlassEffectView provides its own shadow
        self.isMovableByWindowBackground = true  // Allow dragging by clicking anywhere
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Setup Liquid Glass view
        liquidGlassView = LiquidGlassView(frame: windowRect)
        self.contentView = liquidGlassView

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

        // Store original position
        let finalOrigin = self.frame.origin

        // Start slightly higher for floating entrance
        self.setFrameOrigin(NSPoint(x: finalOrigin.x, y: finalOrigin.y + 20))

        // Fade in + float down animation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.5
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1.0) // Gentle bounce
            self.animator().alphaValue = 1.0
            self.animator().setFrameOrigin(finalOrigin)
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
        liquidGlassView.updateAudioLevel(level)
    }
}
