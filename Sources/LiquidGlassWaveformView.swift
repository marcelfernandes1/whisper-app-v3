import Cocoa
import QuartzCore

class LiquidGlassWaveformView: NSView {
    private var bars: [NSView] = []
    private let numberOfBars = 5
    private let barWidth: CGFloat = 5
    private let barSpacing: CGFloat = 4

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

        // Create simple bars
        let totalWidth = CGFloat(numberOfBars) * barWidth + CGFloat(numberOfBars - 1) * barSpacing
        let startX = (bounds.width - totalWidth) / 2

        for i in 0..<numberOfBars {
            let x = startX + CGFloat(i) * (barWidth + barSpacing)
            let initialHeight: CGFloat = 24
            let y = bounds.midY - initialHeight / 2

            let bar = NSView(frame: CGRect(x: x, y: y, width: barWidth, height: initialHeight))
            bar.wantsLayer = true
            bar.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.8).cgColor
            bar.layer?.cornerRadius = barWidth / 2

            addSubview(bar)
            bars.append(bar)

            // Start idle animation with delay
            startIdleAnimation(for: bar, delay: Double(i) * 0.1)
        }
    }

    private func startIdleAnimation(for bar: NSView, delay: TimeInterval = 0) {
        // Gentle breathing animation when idle
        Timer.scheduledTimer(withTimeInterval: 0.2 + delay, repeats: true) { [weak bar, weak self] timer in
            guard let bar = bar, let self = self else {
                timer.invalidate()
                return
            }

            Task { @MainActor in
                let randomHeight = CGFloat.random(in: 18...32)
                self.animateBarToHeight(bar, targetHeight: randomHeight, duration: 0.8)
            }
        }
    }

    func updateAudioLevel(_ level: CGFloat) {
        let normalizedLevel = max(0.2, min(1.0, level))

        for bar in bars {
            let variation = CGFloat.random(in: 0.85...1.15)
            let targetHeight = 16 + (normalizedLevel * 40 * variation)

            animateBarToHeight(bar, targetHeight: targetHeight, duration: 0.15)
        }
    }

    private func animateBarToHeight(_ bar: NSView, targetHeight: CGFloat, duration: TimeInterval) {
        let y = bounds.midY - targetHeight / 2

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true

            bar.frame = CGRect(x: bar.frame.minX, y: y, width: barWidth, height: targetHeight)
        })
    }

    override func layout() {
        super.layout()

        let totalWidth = CGFloat(numberOfBars) * barWidth + CGFloat(numberOfBars - 1) * barSpacing
        let startX = (bounds.width - totalWidth) / 2

        for (i, bar) in bars.enumerated() {
            let x = startX + CGFloat(i) * (barWidth + barSpacing)
            let currentHeight = bar.frame.height
            let y = bounds.midY - currentHeight / 2
            bar.frame = CGRect(x: x, y: y, width: barWidth, height: currentHeight)
        }
    }
}
