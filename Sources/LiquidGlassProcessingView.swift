import Cocoa

class LiquidGlassProcessingView: NSView {
    private var spinner: NSProgressIndicator!
    private var label: NSTextField!

    // Enable vibrancy for Liquid Glass
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

        // Create spinning progress indicator
        spinner = NSProgressIndicator(frame: .zero)
        spinner.style = .spinning
        spinner.controlSize = .regular
        spinner.isIndeterminate = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        addSubview(spinner)

        // Create label
        label = NSTextField(labelWithString: "Transcribing...")
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        // Layout constraints - centered vertically, stacked
        NSLayoutConstraint.activate([
            // Spinner centered horizontally, slightly above center
            spinner.centerXAnchor.constraint(equalTo: centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -10),

            // Label centered horizontally, below spinner
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 8),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16)
        ])

        // Start spinner animation
        spinner.startAnimation(nil)
    }
}
