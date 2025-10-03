#!/usr/bin/env python3
"""
Persistent transcription daemon for WhisperTranscribe app
Loads the Whisper model once and keeps it in memory for fast transcriptions
"""

import sys
import json
import warnings
import traceback

# Suppress warnings for cleaner output
warnings.filterwarnings("ignore")

# Global model variable
model = None
model_name = None


def load_model(requested_model_name):
    """Load the Whisper model into memory"""
    global model, model_name

    try:
        import time
        from pywhispercpp.model import Model

        # Only load if not already loaded or if different model requested
        if model is None or model_name != requested_model_name:
            print(json.dumps({
                "status": "info",
                "message": f"🔄 Loading Whisper model '{requested_model_name}'..."
            }), file=sys.stderr, flush=True)

            start_time = time.time()
            model = Model(requested_model_name, n_threads=4)
            model_name = requested_model_name
            load_time = time.time() - start_time

            print(json.dumps({
                "status": "ready",
                "message": f"✅ Model '{requested_model_name}' loaded in {load_time:.2f}s and ready"
            }), file=sys.stderr, flush=True)
        else:
            print(json.dumps({
                "status": "info",
                "message": f"♻️  Model '{requested_model_name}' already loaded (reusing)"
            }), file=sys.stderr, flush=True)

        return True
    except Exception as e:
        print(json.dumps({
            "status": "error",
            "message": f"❌ Failed to load model: {str(e)}"
        }), file=sys.stderr, flush=True)
        return False


def transcribe_audio(audio_file_path, language="auto"):
    """
    Transcribe audio file using the pre-loaded model

    Args:
        audio_file_path: Path to the audio file (WAV format)
        language: Language code (e.g., "en", "pt", "es") or "auto" for auto-detect

    Returns:
        Transcribed text or None on error
    """
    import time
    global model

    if model is None:
        return None, "Model not loaded"

    try:
        print(json.dumps({
            "status": "info",
            "message": f"🎯 Starting transcription (language: {language})..."
        }), file=sys.stderr, flush=True)

        start_time = time.time()

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

        transcribe_time = time.time() - start_time
        result = " ".join(text_parts).strip()

        print(json.dumps({
            "status": "info",
            "message": f"✅ Transcription completed in {transcribe_time:.2f}s ({len(result)} chars)"
        }), file=sys.stderr, flush=True)

        return result, None

    except Exception as e:
        print(json.dumps({
            "status": "error",
            "message": f"❌ Transcription error: {str(e)}"
        }), file=sys.stderr, flush=True)
        return None, f"Transcription error: {str(e)}"


def handle_request(request):
    """Handle a single JSON request"""
    try:
        data = json.loads(request)
        action = data.get("action")

        print(json.dumps({
            "status": "info",
            "message": f"📨 Received request: {action}"
        }), file=sys.stderr, flush=True)

        if action == "transcribe":
            audio_path = data.get("audio_path")
            language = data.get("language", "auto")
            model_to_use = data.get("model", "small")

            print(json.dumps({
                "status": "info",
                "message": f"📂 Audio: {audio_path}"
            }), file=sys.stderr, flush=True)

            if not audio_path:
                return json.dumps({
                    "status": "error",
                    "message": "Missing audio_path parameter"
                })

            # Ensure model is loaded
            if not load_model(model_to_use):
                return json.dumps({
                    "status": "error",
                    "message": "Failed to load model"
                })

            # Perform transcription
            text, error = transcribe_audio(audio_path, language)

            if error:
                return json.dumps({
                    "status": "error",
                    "message": error
                })

            if not text:
                return json.dumps({
                    "status": "error",
                    "message": "Empty transcription"
                })

            print(json.dumps({
                "status": "info",
                "message": f"📤 Sending response with {len(text)} characters"
            }), file=sys.stderr, flush=True)

            return json.dumps({
                "status": "success",
                "text": text
            })

        elif action == "load_model":
            model_to_use = data.get("model", "small")

            if load_model(model_to_use):
                return json.dumps({
                    "status": "success",
                    "message": f"Model '{model_to_use}' loaded"
                })
            else:
                return json.dumps({
                    "status": "error",
                    "message": "Failed to load model"
                })

        elif action == "ping":
            print(json.dumps({
                "status": "info",
                "message": "🏓 Pong!"
            }), file=sys.stderr, flush=True)
            return json.dumps({
                "status": "success",
                "message": "pong"
            })

        elif action == "shutdown":
            print(json.dumps({
                "status": "info",
                "message": "🛑 Shutdown requested"
            }), file=sys.stderr, flush=True)
            return json.dumps({
                "status": "success",
                "message": "shutting down"
            })

        else:
            return json.dumps({
                "status": "error",
                "message": f"Unknown action: {action}"
            })

    except json.JSONDecodeError as e:
        return json.dumps({
            "status": "error",
            "message": f"Invalid JSON: {str(e)}"
        })
    except Exception as e:
        return json.dumps({
            "status": "error",
            "message": f"Request handling error: {str(e)}",
            "traceback": traceback.format_exc()
        })


def main():
    """Main daemon loop - reads JSON requests from stdin, writes responses to stdout"""

    # Signal that daemon is starting
    print(json.dumps({
        "status": "starting",
        "message": "🚀 Transcription daemon starting..."
    }), file=sys.stderr, flush=True)

    print(json.dumps({
        "status": "info",
        "message": "👂 Listening for requests on stdin..."
    }), file=sys.stderr, flush=True)

    request_count = 0

    try:
        # Main request loop
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue

            request_count += 1
            print(json.dumps({
                "status": "info",
                "message": f"📩 Request #{request_count} received"
            }), file=sys.stderr, flush=True)

            # Process request
            response = handle_request(line)

            # Send response
            print(response, flush=True)

            print(json.dumps({
                "status": "info",
                "message": f"✉️  Response #{request_count} sent"
            }), file=sys.stderr, flush=True)

            # Check if shutdown was requested
            try:
                response_data = json.loads(response)
                if response_data.get("message") == "shutting down":
                    break
            except:
                pass

    except KeyboardInterrupt:
        print(json.dumps({
            "status": "info",
            "message": "⚠️  Daemon interrupted"
        }), file=sys.stderr, flush=True)
    except Exception as e:
        print(json.dumps({
            "status": "error",
            "message": f"❌ Daemon error: {str(e)}",
            "traceback": traceback.format_exc()
        }), file=sys.stderr, flush=True)
        sys.exit(1)

    # Clean shutdown
    print(json.dumps({
        "status": "stopped",
        "message": f"🛑 Daemon stopped (processed {request_count} requests)"
    }), file=sys.stderr, flush=True)


if __name__ == "__main__":
    main()
