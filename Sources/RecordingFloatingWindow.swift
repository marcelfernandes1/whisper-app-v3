import Cocoa

@MainActor
class RecordingFloatingWindow: NSPanel {
    enum State {
        case recording
        case processing
        case error
    }

    private var glassContainer: NSView?  // Either NSGlassEffectView (macOS 26+) or NSVisualEffectView
    private var visualEffectView: NSVisualEffectView?
    private var currentContentView: NSView?
    private var currentState: State = .recording

    // State-specific views
    private var recordingView: NSView!
    private var processingView: LiquidGlassProcessingView!
    private var errorView: LiquidGlassErrorView!
    private var timerLabel: NSTextField!

    init() {
        // Window size for Liquid Glass floating indicator (fixed for all states)
        let windowRect = NSRect(x: 0, y: 0, width: 250, height: 120)

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

        // Setup state-specific views
        setupViews(windowRect: windowRect)

        // Position window at top-right of screen
        positionWindow()

        // Start hidden
        self.alphaValue = 0
    }

    private func setupViews(windowRect: NSRect) {
        // Create recording view (microphone + waveforms + timer)
        let contentContainer = NSView(frame: windowRect)
        contentContainer.autoresizingMask = [.width, .height]

        // Calculate vertical center for all elements
        let elementHeight: CGFloat = 40
        let centerY = (windowRect.height - elementHeight) / 2

        // Microphone icon (left)
        let micFrame = CGRect(x: 12, y: centerY, width: 40, height: elementHeight)
        let microphoneView = LiquidGlassMicrophoneView(frame: micFrame)
        microphoneView.autoresizingMask = [.maxXMargin]
        contentContainer.addSubview(microphoneView)

        // Waveform (center) - scrolling Voice Memos style
        let waveformFrame = CGRect(x: 65, y: centerY, width: 122, height: elementHeight)
        let waveformView = LiquidGlassScrollingWaveformView(frame: waveformFrame)
        waveformView.autoresizingMask = [.minXMargin, .maxXMargin]
        contentContainer.addSubview(waveformView)

        // Timer label (right) - use appropriate height for font size
        let fontSize: CGFloat = 15
        let timerHeight: CGFloat = 20  // Appropriate for 15pt font
        let timerY = (windowRect.height - timerHeight) / 2  // Center the 20pt frame

        let timerFrame = CGRect(x: 178, y: timerY, width: 60, height: timerHeight)
        timerLabel = NSTextField(labelWithString: "0:00")
        timerLabel.frame = timerFrame
        timerLabel.font = .monospacedDigitSystemFont(ofSize: fontSize, weight: .regular)
        timerLabel.textColor = .secondaryLabelColor
        timerLabel.alignment = .right
        timerLabel.isBordered = false
        timerLabel.isEditable = false
        timerLabel.drawsBackground = false
        timerLabel.autoresizingMask = [.minXMargin]
        contentContainer.addSubview(timerLabel)

        recordingView = contentContainer

        // Create processing view
        processingView = LiquidGlassProcessingView(frame: windowRect)
        processingView.autoresizingMask = [.width, .height]

        // Create error view
        errorView = LiquidGlassErrorView(frame: windowRect)
        errorView.autoresizingMask = [.width, .height]

        // Setup glass container with recording view as initial content
        let containerView = NSView(frame: windowRect)
        containerView.autoresizingMask = [.width, .height]

        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.frame = windowRect
            glass.cornerRadius = 24
            glass.tintColor = .clear
            glass.contentView = recordingView
            glass.autoresizingMask = [.width, .height]
            containerView.addSubview(glass)
            glassContainer = glass
        } else {
            // Fallback for older macOS versions
            let visualEffect = NSVisualEffectView(frame: windowRect)
            visualEffect.material = .underWindowBackground
            visualEffect.blendingMode = .behindWindow
            visualEffect.state = .active
            visualEffect.wantsLayer = true
            visualEffect.layer?.cornerRadius = 24
            visualEffect.autoresizingMask = [.width, .height]
            containerView.addSubview(visualEffect)
            containerView.addSubview(recordingView)
            visualEffectView = visualEffect
        }

        currentContentView = recordingView
        self.contentView = containerView
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
        // Reset to recording state BEFORE showing
        if currentState != .recording {
            currentState = .recording
            recordingView.alphaValue = 1.0
            if #available(macOS 26.0, *), let glass = glassContainer as? NSGlassEffectView {
                glass.contentView = recordingView
            } else {
                currentContentView?.removeFromSuperview()
                if let containerView = contentView {
                    containerView.addSubview(recordingView)
                }
            }
            currentContentView = recordingView
        }

        // Reset timer to 0:00
        resetTimer()

        // Reset waveform for new recording
        if let recordingView = recordingView {
            for subview in recordingView.subviews {
                if let waveformView = subview as? LiquidGlassScrollingWaveformView {
                    waveformView.reset()
                }
            }
        }

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
        // Only update if in recording state
        guard currentState == .recording else { return }

        // Update recording view subviews (microphone and waveform)
        if let recordingView = recordingView {
            for subview in recordingView.subviews {
                if let micView = subview as? LiquidGlassMicrophoneView {
                    micView.updateAudioLevel(level)
                } else if let waveformView = subview as? LiquidGlassScrollingWaveformView {
                    waveformView.addSample(level)
                }
            }
        }
    }

    func updateDuration(_ duration: TimeInterval) {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        timerLabel.stringValue = String(format: "%d:%02d", mins, secs)
    }

    func resetTimer() {
        timerLabel.stringValue = "0:00"
    }

    func showProcessing() {
        currentState = .processing
        transitionToView(processingView)
    }

    func showError(message: String, onRetry: @escaping () -> Void, onCancel: @escaping () -> Void) {
        currentState = .error
        errorView.configure(message: message, onRetry: onRetry, onCancel: onCancel)
        transitionToView(errorView)
    }

    func showRecording() {
        currentState = .recording
        transitionToView(recordingView)
    }

    private func transitionToView(_ newView: NSView) {
        guard let oldView = currentContentView, oldView != newView else { return }

        // Fade out old view
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            oldView.animator().alphaValue = 0
        }, completionHandler: {
            Task { @MainActor in
                // Swap views
                if #available(macOS 26.0, *), let glass = self.glassContainer as? NSGlassEffectView {
                    // For NSGlassEffectView, update contentView
                    glass.contentView = newView
                } else {
                    // For NSVisualEffectView, manage subviews manually
                    oldView.removeFromSuperview()
                    if let containerView = self.contentView {
                        containerView.addSubview(newView)
                    }
                }

                newView.alphaValue = 0
                self.currentContentView = newView

                // Fade in new view
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.3
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    newView.animator().alphaValue = 1
                })
            }
        })
    }
}
