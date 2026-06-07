#!/bin/bash
# YouTube Audio Downloader
# Downloads audio from YouTube using yt-dlp and converts to WAV
# Usage: yt-dl "https://www.youtube.com/watch?v=VIDEO_ID" [format] [quality] [options]

set -e

if [ $# -eq 0 ]; then
    echo "Usage: yt-dl <URL> [audio-format] [quality] [options]"
    echo ""
    echo "Examples:"
    echo "  yt-dl \"https://www.youtube.com/watch?v=dQw4w9WgXcQ\""
    echo "  yt-dl \"https://www.youtube.com/watch?v=dQw4w9WgXcQ\" mp3"
    echo "  yt-dl \"https://www.youtube.com/watch?v=dQw4w9WgXcQ\" wav 192"
    echo "  yt-dl \"https://www.youtube.com/watch?v=dQw4w9WgXcQ\" wav best --lyrics --lyrics-lang en"
    echo "  yt-dl \"https://www.youtube.com/watch?v=dQw4w9WgXcQ\" mp3 best --auto-lyrics"
    echo "  yt-dl \"https://www.youtube.com/watch?v=dQw4w9WgXcQ\" wav best --transcribe"
    echo ""
    echo "Supported audio formats: mp3, m4a, opus, vorbis, wav"
    echo "Default format: wav"
    echo "Default quality: best"
    echo ""
    echo "Options:"
    echo "  --lyrics                Prefer creator subtitles and fall back to auto subtitles"
    echo "  --auto-lyrics           Download auto-generated subtitles"
    echo "  --lyrics-lang <code>    Subtitle language (default: en)"
    echo "  --transcribe            Download audio, then run Whisper transcription"
    echo "  --transcribe-model <m>  Whisper model: tiny/base/small/medium/large (default: small)"
    echo "  If you already have the audio or a YouTube URL, run: yt-lyrics <file-or-url>"
    exit 1
fi

URL="$1"
FORMAT="${2:-wav}"
QUALITY="${3:-best}"
LYRICS_MODE="none"
LYRICS_LANG="en"
TRANSCRIBE="false"
TRANSCRIBE_MODEL="small"

shift $(( $# > 3 ? 3 : $# ))

while [ $# -gt 0 ]; do
    case "$1" in
        --lyrics)
            LYRICS_MODE="manual"
            ;;
        --auto-lyrics)
            LYRICS_MODE="auto"
            ;;
        --lyrics-lang)
            shift
            if [ -z "$1" ]; then
                echo "Error: --lyrics-lang requires a language code (example: en)"
                exit 1
            fi
            LYRICS_LANG="$1"
            ;;
        --transcribe)
            TRANSCRIBE="true"
            ;;
        --transcribe-model)
            shift
            if [ -z "$1" ]; then
                echo "Error: --transcribe-model requires a model name"
                exit 1
            fi
            TRANSCRIBE_MODEL="$1"
            ;;
        *)
            echo "Error: Unknown option: $1"
            exit 1
            ;;
    esac
    shift
done

# Validate URL
if [[ ! "$URL" =~ youtube.com|youtu.be ]]; then
    echo "Error: Invalid YouTube URL"
    exit 1
fi

# Set output directory
OUTPUT_DIR="$HOME/Documents/SJC_Songs"
LYRICS_OUTPUT_DIR="$HOME/Documents/SJC_Lyrics"
mkdir -p "$OUTPUT_DIR"
mkdir -p "$LYRICS_OUTPUT_DIR"

echo "📥 Downloading audio from YouTube..."
echo "URL: $URL"
echo "Format: $FORMAT"
echo "Quality: $QUALITY"
echo "Lyrics mode: $LYRICS_MODE"
echo "Lyrics language: $LYRICS_LANG"
echo "Transcribe: $TRANSCRIBE"
echo "Transcribe model: $TRANSCRIBE_MODEL"
echo "Output: $OUTPUT_DIR"
echo "Lyrics output: $LYRICS_OUTPUT_DIR"
echo ""

YT_DLP_ARGS=(
    -x
    --audio-format "$FORMAT"
    --audio-quality "$QUALITY"
    -o "$OUTPUT_DIR/%(title)s.%(ext)s"
)

# Keep subtitle output in SRT so it's readable and timestamped.
if [ "$LYRICS_MODE" = "manual" ]; then
    YT_DLP_ARGS+=(
        --write-subs
        --write-auto-subs
        --sub-langs "$LYRICS_LANG"
        --sub-format "best"
        --convert-subs "srt"
    )
elif [ "$LYRICS_MODE" = "auto" ]; then
    YT_DLP_ARGS+=(
        --write-auto-subs
        --sub-langs "$LYRICS_LANG"
        --sub-format "best"
        --convert-subs "srt"
    )
fi

# Download audio (and optional synced subtitles)
DOWNLOAD_OUTPUT="$(yt-dlp "${YT_DLP_ARGS[@]}" --print after_move:filepath "$URL")"
echo "$DOWNLOAD_OUTPUT"
DOWNLOADED_FILE="$(printf '%s\n' "$DOWNLOAD_OUTPUT" | tail -n 1)"

echo ""
echo "✅ Download complete!"
echo "File saved to: $OUTPUT_DIR"

if [ "$LYRICS_MODE" != "none" ]; then
    echo "Lyrics saved as .srt in: $OUTPUT_DIR"
fi

if [ "$TRANSCRIBE" = "true" ]; then
    if [ ! -f "$DOWNLOADED_FILE" ]; then
        echo "Warning: could not determine downloaded file path for transcription"
    else
        echo ""
        echo "🎙️  Running transcription + lyric formatting..."
        bash "$(dirname "$0")/lyrics-transcribe.sh" \
            "$DOWNLOADED_FILE" \
            --model "$TRANSCRIBE_MODEL" \
            --lang "$LYRICS_LANG" \
            --out-dir "$LYRICS_OUTPUT_DIR"
    fi
fi
