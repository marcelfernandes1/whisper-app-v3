# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

WhisperTranscribe is a macOS menu bar application for local voice transcription using whisper.cpp (via Python bindings). The app provides global hotkey activation (double-tap Ctrl) and automatically pastes transcribed text into any application. Processing is entirely local using a persistent Python daemon for fast performance.

## Build and Development Commands

### Initial Setup
```bash
./setup.sh                    # Install Python dependencies in venv
```

### Build App Bundle
```bash
./build.sh                    # Bundles daemon, builds Swift app, creates .app bundle
```

This script:
1. Runs `bundle_daemon.sh` to create a standalone Python executable with PyInstaller
2. Builds the Swift app with `swift build -c release`
3. Creates the `.app` bundle structure and copies the bundled daemon to Resources

### Build DMG for Distribution
```bash
./create_dmg.sh              # Create basic DMG installer
./create_pretty_dmg.sh       # Create styled DMG with custom background
```

### Complete Distribution Build (Zero-Setup DMG)

To create a fully self-contained DMG that users can install without any Python setup:

```bash
# 1. Ensure venv is set up with correct dependencies
./setup.sh

# 2. Build everything (bundles daemon + builds app + creates .app bundle)
./build.sh

# 3. Create distributable DMG
./create_dmg.sh
```

The resulting `WhisperTranscribe-1.0.dmg` contains:
- Fully bundled `.app` with standalone daemon executable in Resources
- All dependencies embedded (no Python installation required)
- Users just drag to Applications and run

**What gets bundled:**
- `WhisperTranscribe.app/Contents/MacOS/WhisperTranscribe` - Swift executable
- `WhisperTranscribe.app/Contents/Resources/transcribe_daemon` - Standalone Python executable with all dependencies (PyInstaller bundle)
- `WhisperTranscribe.app/Contents/Resources/AppIcon.icns` - App icon

The daemon is created by PyInstaller as a single executable that includes Python interpreter, pywhispercpp, and all dependencies.

### Development
```bash
swift build                  # Build debug version
swift run                    # Build and run directly (for testing)
swift build -c release       # Build release version
```

## Architecture

### Two-Process Design
The app consists of two processes that communicate via stdin/stdout:

1. **Swift Menu Bar App** (`Sources/`)
   - Menu bar UI and system integration
   - Audio recording (16kHz mono WAV)
   - Global hotkey detection (Ctrl double-tap)
   - Text insertion via clipboard + Cmd+V simulation
   - Floating "Liquid Glass" UI window with waveform visualization

2. **Python Transcription Daemon** (`transcribe_daemon.py`)
   - Persistent process that stays running
   - Loads Whisper model once on first transcription (3x faster subsequent transcriptions)
   - Listens for JSON requests on stdin, returns JSON responses on stdout
   - Uses `pywhispercpp` (whisper.cpp Python bindings) for fast inference
   - Bundled as standalone executable using PyInstaller

### Communication Protocol
The Swift app sends JSON requests to the daemon:
```json
{"action": "transcribe", "audio_path": "/path/to/audio.wav", "model": "small", "language": "auto"}
```

The daemon responds with:
```json
{"status": "success", "text": "transcribed text"}
```

### Key Components

**Swift Components:**
- `AppDelegate.swift` - Main app controller, coordinates all components
- `TranscriptionEngine.swift` - Manages daemon process lifecycle and communication
- `HotkeyManager.swift` - Global hotkey detection using CGEvent tap (Ctrl double-tap with 400ms threshold)
- `AudioRecorder.swift` - AVFoundation audio recording with level monitoring
- `TextInserter.swift` - Text insertion using clipboard + AppleScript Cmd+V simulation
- `RecordingFloatingWindow.swift` - Multi-state floating window (recording/processing/error)
- `LiquidGlass*.swift` views - Visual components using NSGlassEffectView (macOS 26+) or NSVisualEffectView fallback

**Python Components:**
- `transcribe_daemon.py` - Persistent daemon using `pywhispercpp` (whisper.cpp bindings) for transcription
- `transcribe.py` - Legacy single-use script (deprecated, kept for reference)

**Dependencies:**
- Core: `pywhispercpp>=1.3.3` for whisper.cpp Python bindings
- Build: `pyinstaller>=6.0.0` for creating standalone daemon executable
- See `requirements.txt` for full dependency list

### State Management
The floating window has three states:
- **Recording**: Shows microphone icon, scrolling waveform, and timer
- **Processing**: Shows processing spinner after recording stops
- **Error**: Shows error message with Retry/Cancel buttons

The app maintains retry capability by storing the audio file URL until transcription succeeds or user cancels.

### Model Configuration
Whisper model is configured in `TranscriptionEngine.swift:4`:
```swift
private let modelName = "small" // Options: tiny, base, small, medium, large
```

Models are auto-downloaded on first use and cached in `~/.cache/whisper/`.

### Daemon Bundling
The daemon is bundled as a standalone executable to simplify distribution:
- `bundle_daemon.sh` uses PyInstaller to create `dist_daemon/transcribe_daemon`
- The executable includes Python, all dependencies, and Whisper model loader
- Built app bundles include the daemon in `WhisperTranscribe.app/Contents/Resources/transcribe_daemon`
- No need for users to install Python or dependencies

### Language Support
Language selection is available in the menu bar:
- Auto-detect (default)
- Portuguese (Brazil), English, Spanish, French, German, Italian, Japanese
- Language preference stored in UserDefaults as "transcriptionLanguage"

### Microphone Selection
Users can select a specific microphone or use auto-detect (system default). Selection is managed by `AudioRecorder.swift` and stored via UserDefaults.

## Important Implementation Details

### Daemon Lifecycle
- Daemon starts asynchronously on app launch
- Model loads lazily on first transcription request
- Daemon auto-restarts if process dies
- Graceful shutdown via `{"action": "shutdown"}` on app quit

### Permissions Required
1. **Microphone access** - For audio recording
2. **Accessibility permissions** - For pasting text into other apps via AppleScript

### Audio Format
Audio is recorded at 16kHz mono 16-bit PCM WAV (optimal for Whisper). This format is hardcoded in `AudioRecorder.swift`.

### Hotkey Detection
Uses CGEvent tap to monitor Ctrl key flags globally. Double-tap detection uses a 400ms window (`HotkeyManager.swift:11`). First tap sets `waitingForSecondTap`, second tap within threshold triggers recording toggle.

### Text Insertion Strategy
Uses clipboard + AppleScript to simulate Cmd+V for maximum compatibility across apps. This approach works in apps that don't accept direct text insertion APIs (Slack, WhatsApp, Terminal, etc.).
