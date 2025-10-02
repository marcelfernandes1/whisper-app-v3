import Cocoa

class LiquidGlassErrorView: NSView {
    private var iconView: NSImageView!
    private var messageLabel: NSTextField!
    private var retryButton: NSButton!
    private var cancelButton: NSButton!

    private var onRetry: (() -> Void)?
    private var onCancel: (() -> Void)?

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

        // Create error icon
        iconView = NSImageView(frame: .zero)
        let errorImage = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Error")!
        let config = NSImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        let configuredImage = errorImage.withSymbolConfiguration(config)
        configuredImage?.isTemplate = true
        iconView.image = configuredImage
        iconView.contentTintColor = .secondaryLabelColor
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        // Create error message label
        messageLabel = NSTextField(wrappingLabelWithString: "Transcription failed")
        messageLabel.font = .systemFont(ofSize: 11)
        messageLabel.textColor = .secondaryLabelColor
        messageLabel.alignment = .center
        messageLabel.maximumNumberOfLines = 2
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(messageLabel)

        // Create button stack
        let buttonStack = NSStackView()
        buttonStack.orientation = .horizontal
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = 8
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        // Retry button
        retryButton = NSButton(title: "Retry", target: self, action: #selector(retryTapped))
        retryButton.bezelStyle = .rounded
        retryButton.translatesAutoresizingMaskIntoConstraints = false

        // Cancel button
        cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelTapped))
        cancelButton.bezelStyle = .rounded
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        buttonStack.addArrangedSubview(cancelButton)
        buttonStack.addArrangedSubview(retryButton)
        addSubview(buttonStack)

        // Layout constraints - vertical stack
        NSLayoutConstraint.activate([
            // Icon at top, centered
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 12),

            // Message below icon
            messageLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            messageLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            // Buttons at bottom
            buttonStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            buttonStack.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 12),
            buttonStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            buttonStack.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    func configure(message: String, onRetry: @escaping () -> Void, onCancel: @escaping () -> Void) {
        messageLabel.stringValue = message
        self.onRetry = onRetry
        self.onCancel = onCancel
    }

    @objc private func retryTapped() {
        onRetry?()
    }

    @objc private func cancelTapped() {
        onCancel?()
    }
}
