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

# Install Whisper
pip install --upgrade openai-whisper

echo "\nSetup complete. To use this venv in the current shell:"
echo "  source venv/bin/activate"

// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "WhisperTranscribe",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "WhisperTranscribe", targets: ["WhisperTranscribe"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "WhisperTranscribe",
            path: "Sources"
        )
    ]
)
