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

### Complete Distribution Build (Zero-Setup DMG)

To create a fully self-contained DMG that users can install without any Python setup:

```bash
# 1. Ensure venv is set up with correct dependencies
./setup.sh

# 2. Build everything (bundles daemon + builds app + creates .app bundle)
./build.sh

# 3. Create distributable DMG with custom background
./create_pretty_dmg.sh
```

The resulting `WhisperTranscribe-1.0.dmg` (14MB) contains:
- Fully bundled `.app` with standalone daemon executable in Resources
- All dependencies embedded (no Python installation required)
- Styled DMG window with custom background and arrow pointing to Applications
- Users just drag to Applications and run

**What gets bundled:**
- `WhisperTranscribe.app/Contents/MacOS/WhisperTranscribe` - Swift executable
- `WhisperTranscribe.app/Contents/Resources/transcribe_daemon` - Standalone Python executable with all dependencies (PyInstaller bundle)
- `WhisperTranscribe.app/Contents/Resources/AppIcon.icns` - Liquid Glass styled app icon

The daemon is created by PyInstaller as a single executable that includes Python interpreter, pywhispercpp, and all dependencies.

### Regenerating Assets (Optional)

If you need to regenerate the app icon or DMG background:

```bash
# Regenerate Liquid Glass app icon (creates AppIcon.icns)
python3 create_liquid_glass_icon.py

# Regenerate DMG background image (creates dmg_background.png)
python3 create_final_dmg_background.py
```

These are already generated and committed, so you only need to run these if modifying the visual design.

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

## Critical Implementation Rules & Limitations

**⚠️ READ THIS SECTION CAREFULLY BEFORE MAKING ANY CODE CHANGES ⚠️**

### Daemon Communication Protocol (CRITICAL)

1. **Request Format Requirements:**
   - ALL daemon requests MUST be valid JSON followed by a newline character (`\n`)
   - Format: `{"action": "...", ...}\n`
   - Missing newline will cause the daemon to hang indefinitely
   - Requests are sent via `daemonInput` FileHandle

2. **Response Reading:**
   - Responses are read from `daemonOutput` FileHandle
   - Must read until a newline character is encountered
   - Use blocking reads with proper loop logic (see `transcribe()` method)
   - NEVER assume immediate availability of response data

3. **Request Serialization:**
   - Daemon processes requests sequentially, one at a time
   - NEVER send multiple requests simultaneously
   - Wait for response before sending next request
   - Preload and transcription requests must be serialized

4. **Available Daemon Actions:**
   - `load_model` - Preload Whisper model (returns when loaded)
   - `transcribe` - Transcribe audio file (returns with text)
   - `ping` - Health check (returns pong)
   - `shutdown` - Graceful shutdown

### Threading & Concurrency (CRITICAL)

1. **Daemon Operations:**
   - Daemon startup happens on `daemonQueue` (background serial queue)
   - ALL daemon communication must be synchronized
   - Use `initLock` to protect initialization state
   - Model preloading blocks the daemon queue (intentional)

2. **Sendable Compliance:**
   - `TranscriptionEngine` uses `@unchecked Sendable` due to daemon state
   - Completion handlers are not `@Sendable` - this is expected
   - Be cautious when adding new concurrent operations

3. **File Operations:**
   - Audio files written on background queue by AudioRecorder
   - Ensure files are flushed before sending path to daemon
   - Daemon expects complete WAV files (partial reads will fail)

### Audio Format Constraints (IMMUTABLE)

1. **Recording Format:**
   - MUST be 16kHz sample rate
   - MUST be mono (1 channel)
   - MUST be 16-bit PCM
   - Format is hardcoded in `AudioRecorder.swift` for Whisper compatibility
   - DO NOT change audio format without understanding Whisper requirements

2. **File Format:**
   - Only WAV files are supported
   - Files must have proper WAV headers
   - Corrupted or incomplete files will cause transcription to fail silently

### Build System Requirements (CRITICAL)

1. **Build Order MUST BE:**
   ```
   bundle_daemon.sh → swift build → create .app bundle
   ```
   - PyInstaller bundling MUST happen first
   - Daemon executable MUST exist before Swift build completes
   - Build script handles this automatically via `build.sh`

2. **PyInstaller Constraints:**
   - Bundling requires active venv with all dependencies
   - Changes to `transcribe_daemon.py` require re-bundling
   - Bundle size is ~14MB (includes Python + deps + Whisper loader)
   - NEVER modify `dist_daemon/` manually - regenerate via `bundle_daemon.sh`

3. **App Bundle Structure:**
   - Daemon MUST be at `Contents/Resources/transcribe_daemon`
   - Icon MUST be at `Contents/Resources/AppIcon.icns`
   - Swift executable MUST be at `Contents/MacOS/WhisperTranscribe`
   - Breaking this structure will prevent app from launching

### macOS Platform Constraints

1. **Permissions (Required):**
   - Microphone permission - App will crash without it
   - Accessibility permission - Text insertion will fail without it
   - Both must be granted in System Preferences before use

2. **Visual Effects:**
   - NSGlassEffectView requires macOS 26+ (Sequoia)
   - App includes NSVisualEffectView fallback for older versions
   - Test both code paths when modifying UI

3. **Global Hotkey:**
   - Requires Accessibility permission
   - CGEvent tap can fail if another app has priority
   - Double-tap timing is 400ms - DO NOT change without user setting

4. **Text Insertion:**
   - AppleScript execution requires Accessibility permission
   - Clipboard approach is required for compatibility
   - Some apps (sandboxed) may still reject automated paste

### Model & Transcription Constraints

1. **Whisper Models:**
   - Valid models: `tiny`, `base`, `small`, `medium`, `large`
   - Models auto-download on first use (~140MB for small model)
   - Downloaded to `~/.cache/whisper/` (user's home directory)
   - Model loading takes 0.2-0.5s (Metal GPU acceleration)
   - Transcription takes 0.3-1.0s depending on audio length

2. **Language Detection:**
   - `auto` triggers Whisper's language detection
   - Specific language codes (`en`, `pt`, `es`) skip detection
   - Detection adds minimal overhead (~0.1s)

3. **Performance:**
   - First transcription: ~11s (includes model loading)
   - Subsequent transcriptions: ~0.3-0.5s (model cached)
   - Model stays in memory until daemon shutdown

### File Operation Rules (CRITICAL)

1. **Before Editing ANY File:**
   - MUST use Read tool first to see current contents
   - NEVER edit a file without reading it first
   - Edit tool will fail if file not previously read

2. **Before Writing New Files:**
   - MUST use Read tool first if file exists
   - ONLY create new files if absolutely necessary
   - PREFER editing existing files over creating new ones

3. **Code Modifications:**
   - Read the ENTIRE file before making changes
   - Understand context around the change
   - Preserve exact indentation (tabs vs spaces)

### Common Pitfalls to Avoid

1. **Daemon Communication:**
   - ❌ Forgetting newline in requests → Daemon hangs
   - ❌ Not reading full response → Pipe buffer fills
   - ❌ Concurrent requests → Race conditions
   - ✅ Always append `\n` to requests
   - ✅ Read until newline in response
   - ✅ Serialize all daemon communication

2. **Build Process:**
   - ❌ Building Swift before bundling daemon → Missing daemon
   - ❌ Forgetting to rebuild after daemon changes → Stale code
   - ❌ Running PyInstaller without venv → Missing dependencies
   - ✅ Always use `./build.sh` for complete builds
   - ✅ Re-bundle daemon after Python code changes

3. **Audio Recording:**
   - ❌ Changing audio format → Transcription fails
   - ❌ Not flushing audio file → Daemon reads partial file
   - ❌ Deleting temp files too early → File not found errors
   - ✅ Keep 16kHz mono 16-bit PCM format
   - ✅ Ensure files are complete before transcribing

4. **Threading:**
   - ❌ Accessing daemon state without locks → Race conditions
   - ❌ Blocking main thread with daemon I/O → UI freezes
   - ❌ Assuming immediate daemon response → Deadlocks
   - ✅ Use proper queue synchronization
   - ✅ Keep daemon I/O on background queues

### Testing Constraints

1. **Manual Testing Required:**
   - Hotkey detection (must test with real keyboard)
   - Microphone recording (must test with real mic)
   - Text insertion (must test in target applications)
   - Permissions (must grant in System Preferences)

2. **Daemon Testing:**
   - Test daemon bundling with `./bundle_daemon.sh`
   - Verify daemon executable works: `./dist_daemon/transcribe_daemon`
   - Test daemon communication with manual JSON input
   - Monitor stderr output for daemon status messages

3. **Build Verification:**
   - Check daemon exists: `ls WhisperTranscribe.app/Contents/Resources/transcribe_daemon`
   - Check icon exists: `ls WhisperTranscribe.app/Contents/Resources/AppIcon.icns`
   - Test app bundle: `./WhisperTranscribe.app/Contents/MacOS/WhisperTranscribe`

### Code Modification Guidelines

1. **When Adding New Features:**
   - Consider daemon communication if transcription-related
   - Consider thread safety for concurrent operations
   - Consider build impact (daemon bundling, assets)
   - Test with actual hardware (mic, keyboard)

2. **When Debugging Issues:**
   - Check daemon stderr output (printed with 📋 prefix)
   - Verify daemon process is running (`ps aux | grep transcribe_daemon`)
   - Check audio file format (`afinfo <audio_file.wav>`)
   - Verify JSON request format (print before sending)

3. **When Refactoring:**
   - DO NOT break daemon communication protocol
   - DO NOT change audio format
   - DO NOT modify build order
   - DO test complete build and run after changes

### Emergency Troubleshooting

1. **Daemon Not Responding:**
   - Check if process is running
   - Verify stdin/stdout pipes are open
   - Check for JSON formatting errors in requests
   - Look for stderr messages

2. **Transcription Fails:**
   - Verify audio file exists and is complete
   - Check audio format (must be 16kHz mono WAV)
   - Ensure model is loaded (first request takes longer)
   - Check daemon stderr for error messages

3. **Build Fails:**
   - Ensure venv is activated and dependencies installed
   - Verify PyInstaller can access all dependencies
   - Check for Python import errors in daemon
   - Ensure sufficient disk space (~500MB for build)
