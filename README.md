# WhisperTranscribe

A macOS menu bar application for local voice transcription using OpenAI's Whisper model. Replace Apple's default dictation with a powerful, privacy-focused alternative that works in any app.

## Features

- 🎤 **Local transcription** using OpenAI Whisper (no cloud services, all processing on-device)
- ⌨️ **Global hotkey** activation (double-press Ctrl to start/stop)
- 📋 **Universal compatibility** - works in any app: Slack, WhatsApp, Notes, Terminal, etc.
- 🔒 **Privacy-focused** - your voice never leaves your computer
- ⚡ **Multiple model sizes** - choose speed vs. accuracy
- 🎯 **Menu bar app** - lightweight, always accessible

## Requirements

- macOS 13.0 or later
- Python 3.7+ (for Whisper)
- Microphone access
- Accessibility permissions (for pasting text)

## Setup

### 1. Install Python Dependencies

Run the setup script to install OpenAI Whisper and dependencies:

```bash
./setup.sh
```

This will:
- Create a Python virtual environment
- Install `openai-whisper` and dependencies
- Prepare the app for first use

**Note:** The Whisper model will be automatically downloaded on first use (~150 MB for the base model).

### 2. Build the App

```bash
swift build -c release
```

Or create an app bundle:

```bash
./build.sh
```

## Running

### From Terminal

```bash
swift run
```

### From App Bundle

After running `./build.sh`, drag `WhisperTranscribe.app` to `/Applications` and launch it.

## Usage

1. **Launch** - Look for the microphone icon in your menu bar
2. **Start recording** - Double-press the `Ctrl` key
3. **Speak** - The menu bar icon changes to indicate recording
4. **Stop recording** - Double-press `Ctrl` again
5. **Auto-paste** - Transcribed text is automatically pasted into your active application

## Permissions

On first launch, you'll be prompted to grant:

1. **Microphone access** - Required to record audio
   - Settings → Privacy & Security → Microphone

2. **Accessibility permissions** - Required to paste text into other apps
   - Settings → Privacy & Security → Accessibility
   - Enable WhisperTranscribe

## Whisper Models

The app uses OpenAI's Whisper models. You can change the model in `Sources/TranscriptionEngine.swift` by modifying the `modelName` variable.

Available models (from fastest to most accurate):

| Model | Size | Speed | Accuracy | Download |
|-------|------|-------|----------|----------|
| `tiny` | ~75 MB | ⚡⚡⚡⚡⚡ | ⭐⭐ | Auto |
| `base` | ~150 MB | ⚡⚡⚡⚡ | ⭐⭐⭐ | Auto (default) |
| `small` | ~500 MB | ⚡⚡⚡ | ⭐⭐⭐⭐ | Auto |
| `medium` | ~1.5 GB | ⚡⚡ | ⭐⭐⭐⭐⭐ | Auto |
| `large` | ~3 GB | ⚡ | ⭐⭐⭐⭐⭐⭐ | Auto |

Models are automatically downloaded and cached on first use.

## Customization

### Change Hotkey

Edit `Sources/HotkeyManager.swift` and modify the `doubleTapThreshold` or change the key detection logic.

### Change Model

Edit `Sources/TranscriptionEngine.swift`:

```swift
private let modelName = "small" // Change to: tiny, base, small, medium, or large
```

### Recording Quality

Audio is recorded at 16kHz mono (optimal for Whisper). To change, edit `Sources/AudioRecorder.swift`.

## Technical Details

- **Audio format**: 16kHz, mono, 16-bit PCM WAV
- **Hotkey detection**: Global event tap monitoring Ctrl key
- **Text insertion**: Clipboard + simulated Cmd+V for maximum compatibility
- **Transcription**: Python backend using OpenAI Whisper
- **Architecture**: Swift app + Python transcription engine

## Troubleshooting

### "Permission denied" errors
- Grant accessibility permissions in System Preferences
- Check microphone permissions

### "Python not found"
- Ensure Python 3 is installed: `brew install python3`
- Run `./setup.sh` again

### "Whisper model not found"
- The model downloads automatically on first use
- Check internet connection for first run
- Models are cached in `~/.cache/whisper/`

### Transcription not working
- Verify the virtual environment exists: `ls venv/`
- Test Python script manually: `./venv/bin/python3 transcribe.py test.wav`
- Check logs in Terminal when running with `swift run`

## Project Structure

```
whisper-app-v3/
├── Sources/
│   ├── main.swift              # App entry point
│   ├── AppDelegate.swift       # Menu bar app logic
│   ├── HotkeyManager.swift     # Global hotkey detection
│   ├── AudioRecorder.swift     # Audio recording
│   ├── TranscriptionEngine.swift # Whisper integration
│   └── TextInserter.swift      # Text pasting
├── transcribe.py               # Python Whisper script
├── setup.sh                    # Setup script
├── build.sh                    # Build script
├── Package.swift               # Swift package definition
└── README.md                   # This file
```

## License

This project uses OpenAI Whisper, which is licensed under MIT.
