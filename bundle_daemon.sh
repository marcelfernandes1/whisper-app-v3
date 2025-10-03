#!/bin/bash
# Bundle the Python transcription daemon as a standalone executable

set -e

echo "🔧 Bundling transcription daemon with PyInstaller..."

# Activate venv
source venv/bin/activate

# Clean previous builds
rm -rf build_daemon dist_daemon transcribe_daemon.spec

# Bundle with PyInstaller
pyinstaller --onefile \
    --name transcribe_daemon \
    --distpath dist_daemon \
    --workpath build_daemon \
    --clean \
    --noconfirm \
    --console \
    transcribe_daemon.py

# Verify the executable
if [ -f "dist_daemon/transcribe_daemon" ]; then
    echo "✅ Daemon bundled successfully: dist_daemon/transcribe_daemon"
    ls -lh dist_daemon/transcribe_daemon
else
    echo "❌ Failed to bundle daemon"
    exit 1
fi
