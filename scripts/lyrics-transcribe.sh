#!/bin/bash
# Generate stanza-formatted lyrics from a local audio file or YouTube URL using Whisper.
# Retains only the tagged lyrics file by default.
# Usage: lyrics-transcribe.sh <audio-file> [--model MODEL] [--lang CODE] [--out-dir DIR] [--gap-seconds N]

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: lyrics-transcribe.sh <audio-file> [--model MODEL] [--lang CODE] [--out-dir DIR] [--gap-seconds N]"
    echo ""
    echo "Examples:"
    echo "  lyrics-transcribe.sh ~/Documents/SJC_Songs/song.wav"
    echo "  lyrics-transcribe.sh \"https://www.youtube.com/watch?v=VIDEO_ID\""
    echo "  lyrics-transcribe.sh song.mp3 --model medium --lang en --gap-seconds 2.5"
    exit 1
fi

AUDIO_SOURCE="$1"
MODEL="small"
LANG="en"
OUT_DIR=""
GAP_SECONDS="2.2"
DEFAULT_LYRICS_DIR="$HOME/Documents/SJC_Lyrics"
SOURCE_TMP_DIR=""

shift
while [ $# -gt 0 ]; do
    case "$1" in
        --model)
            shift
            MODEL="${1:-}"
            ;;
        --lang)
            shift
            LANG="${1:-}"
            ;;
        --out-dir)
            shift
            OUT_DIR="${1:-}"
            ;;
        --gap-seconds)
            shift
            GAP_SECONDS="${1:-}"
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
    if [ -z "${1:-}" ]; then
        echo "Missing value for previous option"
        exit 1
    fi
    shift
done

is_url=false
case "$AUDIO_SOURCE" in
    http://*|https://*)
        is_url=true
        ;;
esac

if [ "$is_url" = true ]; then
    if ! command -v yt-dlp >/dev/null 2>&1; then
        echo "Error: yt-dlp is required to transcribe from a YouTube URL."
        exit 1
    fi
    SOURCE_TMP_DIR="$(mktemp -d)"
    AUDIO_FILE=""

    echo "Downloading audio to a temporary file..."
    yt-dlp -f bestaudio -o "$SOURCE_TMP_DIR/%(title)s.%(ext)s" "$AUDIO_SOURCE"

    AUDIO_FILE="$(find "$SOURCE_TMP_DIR" -maxdepth 1 -type f | head -n 1)"
    if [ -z "$AUDIO_FILE" ] || [ ! -f "$AUDIO_FILE" ]; then
        echo "Error: failed to download audio from URL"
        exit 1
    fi
else
    AUDIO_FILE="$AUDIO_SOURCE"
    if [ ! -f "$AUDIO_FILE" ]; then
        echo "Error: audio file not found: $AUDIO_FILE"
        exit 1
    fi
fi

WHISPER_BIN=""
if command -v whisper >/dev/null 2>&1; then
    WHISPER_BIN="$(command -v whisper)"
elif [ -x "$HOME/.local/bin/whisper" ]; then
    WHISPER_BIN="$HOME/.local/bin/whisper"
fi

if [ -z "$WHISPER_BIN" ]; then
    echo "Error: whisper CLI is not installed."
    echo "Install with: python3 -m pip install --upgrade openai-whisper"
    echo "or:      pipx install openai-whisper"
    echo "ffmpeg is also required: brew install ffmpeg"
    exit 1
fi

if [ -z "$OUT_DIR" ]; then
    OUT_DIR="$DEFAULT_LYRICS_DIR"
fi
mkdir -p "$OUT_DIR"

BASE_NAME="$(basename "$AUDIO_FILE")"
BASE_NAME="${BASE_NAME%.*}"
JSON_OUT="$OUT_DIR/$BASE_NAME.transcript.json"
PLAIN_OUT="$OUT_DIR/$BASE_NAME.lyrics.txt"
TAGGED_OUT="$OUT_DIR/$BASE_NAME.lyrics.tagged.txt"

TMP_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "$TMP_DIR"
    [ -n "$SOURCE_TMP_DIR" ] && rm -rf "$SOURCE_TMP_DIR"
}
trap cleanup EXIT

echo "Transcribing: $AUDIO_FILE"
echo "Model: $MODEL"
echo "Language: $LANG"

"$WHISPER_BIN" "$AUDIO_FILE" \
    --model "$MODEL" \
    --language "$LANG" \
    --task transcribe \
    --output_format json \
    --output_dir "$TMP_DIR" \
    --fp16 False

TMP_JSON="$TMP_DIR/$BASE_NAME.json"
if [ ! -f "$TMP_JSON" ]; then
    echo "Error: Whisper JSON output not found at $TMP_JSON"
    exit 1
fi

cp "$TMP_JSON" "$JSON_OUT"

python3 "$(dirname "$0")/lyrics-format.py" \
    --input "$JSON_OUT" \
    --plain-output "$PLAIN_OUT" \
    --tagged-output "$TAGGED_OUT" \
    --gap-seconds "$GAP_SECONDS"

rm -f "$JSON_OUT" "$PLAIN_OUT"

echo ""
echo "Done."
echo "Lyrics (tagged): $TAGGED_OUT"
