import Cocoa
import QuartzCore

class LiquidGlassView: NSView {
    private var backgroundView: NSView!
    private var microphoneView: LiquidGlassMicrophoneView!
    private var waveformView: LiquidGlassWaveformView!

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

        // Create content container first
        let contentContainer = NSView(frame: bounds)
        contentContainer.autoresizingMask = [.width, .height]

        // Add microphone on the left
        let micFrame = CGRect(x: 20, y: 0, width: 60, height: bounds.height)
        microphoneView = LiquidGlassMicrophoneView(frame: micFrame)
        microphoneView.autoresizingMask = [.maxXMargin, .height]
        contentContainer.addSubview(microphoneView)

        // Add waveform on the right
        let waveformWidth: CGFloat = 60
        let waveformFrame = CGRect(
            x: bounds.width - waveformWidth - 20,
            y: 0,
            width: waveformWidth,
            height: bounds.height
        )
        waveformView = LiquidGlassWaveformView(frame: waveformFrame)
        waveformView.autoresizingMask = [.minXMargin, .height]
        contentContainer.addSubview(waveformView)

        // Use NSGlassEffectView for macOS 26+, fallback to NSVisualEffectView
        if #available(macOS 26.0, *) {
            let glassView = NSGlassEffectView()
            glassView.frame = bounds
            glassView.cornerRadius = 24
            glassView.tintColor = .clear
            glassView.contentView = contentContainer
            glassView.autoresizingMask = [.width, .height]
            addSubview(glassView)
            backgroundView = glassView
        } else {
            // Fallback for older macOS versions
            let visualEffectView = NSVisualEffectView(frame: bounds)
            visualEffectView.material = .underWindowBackground
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.state = .active
            visualEffectView.wantsLayer = true
            visualEffectView.layer?.cornerRadius = 24
            visualEffectView.autoresizingMask = [.width, .height]
            addSubview(visualEffectView)
            addSubview(contentContainer)
            backgroundView = visualEffectView
        }
    }

    func updateAudioLevel(_ level: CGFloat) {
        microphoneView.updateAudioLevel(level)
        waveformView.updateAudioLevel(level)
    }
}
