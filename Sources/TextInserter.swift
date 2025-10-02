import Cocoa
import ApplicationServices

class TextInserter: @unchecked Sendable {
    func insertText(_ text: String) {
        // Use CGEvent to simulate typing the text
        // This requires accessibility permissions

        // Small delay to ensure the app is ready
        usleep(100_000) // 100ms

        // Method 1: Simulate Command+V (paste)
        // First, copy text to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Simulate Command+V
        let cmdVDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true)
        cmdVDown?.flags = .maskCommand
        cmdVDown?.post(tap: .cghidEventTap)

        let cmdVUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false)
        cmdVUp?.flags = .maskCommand
        cmdVUp?.post(tap: .cghidEventTap)
    }

    // Alternative method: Type character by character (slower but more reliable in some apps)
    func typeText(_ text: String) {
        for char in text {
            if let keyCode = keyCodeForCharacter(char) {
                let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
                keyDown?.post(tap: .cghidEventTap)

                let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
                keyUp?.post(tap: .cghidEventTap)

                usleep(10_000) // Small delay between keystrokes
            }
        }
    }

    private func keyCodeForCharacter(_ character: Character) -> CGKeyCode? {
        // This is a simplified mapping - full implementation would need complete character map
        let charMap: [Character: CGKeyCode] = [
            "a": 0x00, "b": 0x0B, "c": 0x08, "d": 0x02, "e": 0x0E,
            "f": 0x03, "g": 0x05, "h": 0x04, "i": 0x22, "j": 0x26,
            "k": 0x28, "l": 0x25, "m": 0x2E, "n": 0x2D, "o": 0x1F,
            "p": 0x23, "q": 0x0C, "r": 0x0F, "s": 0x01, "t": 0x11,
            "u": 0x20, "v": 0x09, "w": 0x0D, "x": 0x07, "y": 0x10,
            "z": 0x06, " ": 0x31
        ]
        return charMap[Character(character.lowercased())]
    }
}
