import Cocoa
import QuartzCore

class LiquidGlassMicrophoneView: NSView {
    private var micImageView: NSImageView!

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

        // Create simple microphone icon
        let iconSize: CGFloat = 40
        let iconFrame = CGRect(
            x: (bounds.width - iconSize) / 2,
            y: (bounds.height - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )

        micImageView = NSImageView(frame: iconFrame)
        let micImage = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Microphone")!
        let config = NSImage.SymbolConfiguration(pointSize: 36, weight: .semibold)
        micImageView.image = micImage.withSymbolConfiguration(config)
        micImageView.contentTintColor = .labelColor
        micImageView.wantsLayer = true

        addSubview(micImageView)

        // Start subtle breathing animation
        startBreathingAnimation()
    }

    private func startBreathingAnimation() {
        guard let layer = micImageView.layer else { return }

        let breathe = CABasicAnimation(keyPath: "transform.scale")
        breathe.fromValue = 0.98
        breathe.toValue = 1.02
        breathe.duration = 1.5
        breathe.autoreverses = true
        breathe.repeatCount = .infinity
        breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        layer.add(breathe, forKey: "breathe")
    }

    func updateAudioLevel(_ level: CGFloat) {
        // Subtle opacity pulse based on audio level
        let targetOpacity = 0.9 + (level * 0.1)

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.1)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))

        micImageView.layer?.opacity = Float(targetOpacity)

        CATransaction.commit()
    }

    override func layout() {
        super.layout()

        let iconSize: CGFloat = 40
        let iconFrame = CGRect(
            x: (bounds.width - iconSize) / 2,
            y: (bounds.height - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )

        micImageView?.frame = iconFrame
    }
}
