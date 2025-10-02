#!/usr/bin/env python3
"""
Transcription script for WhisperTranscribe app
Uses whisper.cpp with GPU acceleration for blazing fast transcription on Apple Silicon
"""

import sys
import warnings

# Suppress warnings for cleaner output
warnings.filterwarnings("ignore")


def transcribe_audio(audio_file_path, model_name="base", language="auto"):
    """
    Transcribe audio file using whisper.cpp with Metal GPU acceleration

    Args:
        audio_file_path: Path to the audio file (WAV format)
        model_name: Whisper model to use (tiny, base, small, medium, large)
        language: Language code (e.g., "en", "pt", "es") or "auto" for auto-detect

    Returns:
        Transcribed text
    """
    try:
        from pywhispercpp.model import Model

        # Load model with GPU acceleration
        model = Model(model_name, n_threads=4)

        # Transcribe with language parameter (None for auto-detect)
        lang_param = None if language == "auto" else language
        segments = model.transcribe(audio_file_path, language=lang_param)

        # Extract text from segments
        text_parts = []
        for seg in segments:
            # Each segment has a 'text' attribute
            if hasattr(seg, 'text'):
                text_parts.append(seg.text)
            elif isinstance(seg, dict) and 'text' in seg:
                text_parts.append(seg['text'])
            else:
                # Parse string format like "t0=0, t1=360, text=Hello"
                seg_str = str(seg)
                if 'text=' in seg_str:
                    text_part = seg_str.split('text=', 1)[1]
                    text_parts.append(text_part)

        return " ".join(text_parts).strip()

    except Exception as e:
        print(f"Error during transcription: {e}", file=sys.stderr)
        return None


def main():
    if len(sys.argv) < 2:
        print("Usage: transcribe.py <audio_file_path> [model_name] [language]", file=sys.stderr)
        sys.exit(1)

    audio_file = sys.argv[1]
    model_name = sys.argv[2] if len(sys.argv) > 2 else "base"
    language = sys.argv[3] if len(sys.argv) > 3 else "auto"

    # Transcribe
    text = transcribe_audio(audio_file, model_name, language)

    if text:
        # Print only the transcribed text (this is what Swift will capture)
        print(text)
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
