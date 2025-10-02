import Cocoa
import QuartzCore

class RecordingAnimationView: NSView {
    private var microphoneLayer: CALayer!
    private var waveformBars: [NSView] = []
    private let numberOfBars = 5
    private let barWidth: CGFloat = 4
    private let barSpacing: CGFloat = 4
    private var audioLevels: [CGFloat] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 16

        // Initialize audio levels array
        audioLevels = Array(repeating: 0.3, count: numberOfBars)

        // Setup background blur effect - add it first so it's behind
        let visualEffectView = NSVisualEffectView(frame: bounds)
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 16
        visualEffectView.autoresizingMask = [.width, .height]
        addSubview(visualEffectView)

        // Create a container view for the animation content
        let contentView = NSView(frame: bounds)
        contentView.wantsLayer = true
        contentView.layer?.masksToBounds = false
        contentView.autoresizingMask = [.width, .height]
        addSubview(contentView)

        print("🔍 View bounds: \(bounds)")
        print("🔍 Content view frame: \(contentView.frame)")
        print("🔍 Content view has layer: \(contentView.layer != nil)")

        // Setup microphone icon and waveform bars on the content view
        setupMicrophoneIcon(on: contentView)
        setupWaveformBars(on: contentView)

        // Start animations
        startMicrophonePulseAnimation()
        startWaveformAnimation()
    }

    private func setupMicrophoneIcon(on view: NSView) {
        // Create NSImageView for the microphone icon (better rendering)
        let micImageView = NSImageView(frame: CGRect(x: 20, y: bounds.midY - 16, width: 32, height: 32))

        let micImage = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Microphone")!
        let config = NSImage.SymbolConfiguration(pointSize: 32, weight: .medium)
        micImageView.image = micImage.withSymbolConfiguration(config)
        micImageView.contentTintColor = .white
        micImageView.wantsLayer = true

        view.addSubview(micImageView)

        // Store reference to the layer for animation
        microphoneLayer = micImageView.layer
    }

    private func setupWaveformBars(on view: NSView) {
        let totalBarWidth = CGFloat(numberOfBars) * barWidth + CGFloat(numberOfBars - 1) * barSpacing
        let startX = bounds.width - totalBarWidth - 20

        for i in 0..<numberOfBars {
            let x = startX + CGFloat(i) * (barWidth + barSpacing)
            let height: CGFloat = 20 // Initial height
            let y = bounds.midY - height / 2

            let bar = NSView(frame: CGRect(x: x, y: y, width: barWidth, height: height))
            bar.wantsLayer = true
            bar.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.9).cgColor
            bar.layer?.cornerRadius = barWidth / 2

            print("🎵 Adding bar \(i) at x:\(x), y:\(y), height:\(height)")
            view.addSubview(bar)
            waveformBars.append(bar)
        }

        print("✅ Added \(waveformBars.count) waveform bars")
    }

    private func startMicrophonePulseAnimation() {
        // Create pulsing scale animation
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.fromValue = 0.95
        pulseAnimation.toValue = 1.05
        pulseAnimation.duration = 1.0
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        microphoneLayer.add(pulseAnimation, forKey: "pulse")
    }

    private func startWaveformAnimation() {
        // Animate each bar with different phases
        for (index, bar) in waveformBars.enumerated() {
            animateBar(bar, index: index)
        }
    }

    private func animateBar(_ bar: NSView, index: Int) {
        // Animate bar height with random variations for waveform effect
        Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak bar, weak self] _ in
            guard let bar = bar, let self = self else { return }

            Task { @MainActor in
                let randomHeight = CGFloat.random(in: 12...35)
                let y = self.bounds.midY - randomHeight / 2

                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.15
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    bar.animator().frame = CGRect(x: bar.frame.minX, y: y, width: self.barWidth, height: randomHeight)
                })
            }
        }
    }

    func updateAudioLevel(_ level: CGFloat) {
        // Update waveform bars based on actual audio level
        let normalizedLevel = max(0.2, min(1.0, level))

        for bar in waveformBars {
            let variation = CGFloat.random(in: 0.8...1.2)
            let targetHeight = 12 + (normalizedLevel * 30 * variation)
            let y = bounds.midY - targetHeight / 2

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.1
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                bar.animator().frame = CGRect(x: bar.frame.minX, y: y, width: barWidth, height: targetHeight)
            })
        }
    }

    override func layout() {
        super.layout()
        // Subviews have autoresizingMask set, so they'll resize automatically
    }
}
