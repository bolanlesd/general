#!/bin/bash
# YouTube Audio Downloader
# Downloads audio from YouTube using yt-dlp and converts to WAV
# Usage: yt-dl "https://www.youtube.com/watch?v=VIDEO_ID" [format] [quality]

set -e

if [ $# -eq 0 ]; then
    echo "Usage: yt-dl <URL> [audio-format] [quality]"
    echo ""
    echo "Examples:"
    echo "  yt-dl \"https://www.youtube.com/watch?v=dQw4w9WgXcQ\""
    echo "  yt-dl \"https://www.youtube.com/watch?v=dQw4w9WgXcQ\" mp3"
    echo "  yt-dl \"https://www.youtube.com/watch?v=dQw4w9WgXcQ\" wav 192"
    echo ""
    echo "Supported audio formats: mp3, m4a, opus, vorbis, wav"
    echo "Default format: wav"
    echo "Default quality: best"
    exit 1
fi

URL="$1"
FORMAT="${2:-wav}"
QUALITY="${3:-best}"

# Validate URL
if [[ ! "$URL" =~ youtube.com|youtu.be ]]; then
    echo "Error: Invalid YouTube URL"
    exit 1
fi

# Set output directory
OUTPUT_DIR="$HOME/Documents/SJC_Songs"
mkdir -p "$OUTPUT_DIR"

echo "📥 Downloading audio from YouTube..."
echo "URL: $URL"
echo "Format: $FORMAT"
echo "Quality: $QUALITY"
echo "Output: $OUTPUT_DIR"
echo ""

# Download audio
yt-dlp \
    -x \
    --audio-format "$FORMAT" \
    --audio-quality "$QUALITY" \
    -o "$OUTPUT_DIR/%(title)s.%(ext)s" \
    "$URL"

echo ""
echo "✅ Download complete!"
echo "File saved to: $OUTPUT_DIR"
