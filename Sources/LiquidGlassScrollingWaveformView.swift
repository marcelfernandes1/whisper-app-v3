import Cocoa
import QuartzCore

class LiquidGlassScrollingWaveformView: NSView {
    private var barLayers: [CALayer] = []
    private var samples: [CGFloat] = []

    private let maxBars = 40
    private let barWidth: CGFloat = 2
    private let barSpacing: CGFloat = 2
    private let minBarHeight: CGFloat = 8
    private let maxBarHeight: CGFloat = 40

    // Enable vibrancy for Liquid Glass compatibility
    override var allowsVibrancy: Bool { true }

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
        layer?.masksToBounds = true
    }

    func addSample(_ level: CGFloat) {
        // Normalize level to 0.0-1.0 range
        let normalizedLevel = max(0.0, min(1.0, level))

        // Add new sample
        samples.append(normalizedLevel)

        // FIRST: Animate existing bars shifting left to make room
        animateScroll()

        // Calculate bar height based on level
        let barHeight = minBarHeight + (normalizedLevel * (maxBarHeight - minBarHeight))

        // Create new bar layer
        let newBar = createBarLayer(height: barHeight)

        // Position new bar at the right edge (space just cleared by scroll)
        let xPosition = bounds.width - barWidth
        let yPosition = (bounds.height - barHeight) / 2
        newBar.frame = CGRect(x: xPosition, y: yPosition, width: barWidth, height: barHeight)

        layer?.addSublayer(newBar)
        barLayers.append(newBar)

        // Remove oldest bar if we exceed max
        if barLayers.count > maxBars {
            let oldestBar = barLayers.removeFirst()
            samples.removeFirst()
            oldestBar.removeFromSuperlayer()
        }
    }

    private func createBarLayer(height: CGFloat) -> CALayer {
        let bar = CALayer()
        bar.backgroundColor = NSColor.secondaryLabelColor.cgColor
        bar.cornerRadius = barWidth / 2
        return bar
    }

    private func animateScroll() {
        // Use CATransaction to batch all animations
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.05) // Match audio update interval
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .linear))

        // Shift all bars left
        let shiftDistance = barWidth + barSpacing

        for bar in barLayers {
            let currentX = bar.frame.origin.x
            let newX = currentX - shiftDistance

            // Update position
            var newFrame = bar.frame
            newFrame.origin.x = newX
            bar.frame = newFrame
        }

        CATransaction.commit()
    }

    func reset() {
        // Remove all bars
        for bar in barLayers {
            bar.removeFromSuperlayer()
        }
        barLayers.removeAll()
        samples.removeAll()
    }

    override func layout() {
        super.layout()

        // Reposition bars if view size changes
        var xPosition = bounds.width - CGFloat(barLayers.count) * (barWidth + barSpacing)

        for bar in barLayers {
            let barHeight = bar.frame.height
            let yPosition = (bounds.height - barHeight) / 2

            bar.frame = CGRect(x: xPosition, y: yPosition, width: barWidth, height: barHeight)
            xPosition += barWidth + barSpacing
        }
    }
}
