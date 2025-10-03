#!/bin/bash
# Setup script for WhisperTranscribe Python dependencies

set -euo pipefail

echo "Setting up WhisperTranscribe Python environment..."

# Check Python 3
if ! command -v python3 &>/dev/null; then
  echo "Error: Python 3 is not installed. Install with Homebrew: brew install python3" >&2
  exit 1
fi

# Create venv if missing
if [ ! -d "venv" ]; then
  echo "Creating Python virtual environment..."
  python3 -m venv venv
fi

# Activate venv
source venv/bin/activate

# Upgrade pip
python -m pip install --upgrade pip wheel setuptools

# Ensure ffmpeg present (optional but recommended for Whisper)
if ! command -v ffmpeg &>/dev/null; then
  echo "ffmpeg not found. Installing via Homebrew..."
  if command -v brew &>/dev/null; then
    brew install ffmpeg
  else
    echo "Homebrew not installed; please install ffmpeg manually (https://ffmpeg.org)." >&2
  fi
fi

# Install dependencies from requirements.txt
if [ -f "requirements.txt" ]; then
  echo "Installing dependencies from requirements.txt..."
  pip install -r requirements.txt
else
  # Fallback: install manually if requirements.txt missing
  echo "Installing dependencies manually..."
  pip install --upgrade pywhispercpp pyinstaller
fi

echo "\nSetup complete. To use this venv in the current shell:"
echo "  source venv/bin/activate"
