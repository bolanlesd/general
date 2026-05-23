#!/bin/bash
# YouTube Audio Downloader
# Downloads audio from YouTube using yt-dlp and converts to MP3
# Usage: youtube-download "https://www.youtube.com/watch?v=VIDEO_ID" [format] [quality]

set -e

if [ $# -eq 0 ]; then
    echo "Usage: youtube-download <URL> [audio-format] [quality]"
    echo ""
    echo "Examples:"
    echo "  youtube-download \"https://www.youtube.com/watch?v=dQw4w9WgXcQ\""
    echo "  youtube-download \"https://www.youtube.com/watch?v=dQw4w9WgXcQ\" mp3"
    echo "  youtube-download \"https://www.youtube.com/watch?v=dQw4w9WgXcQ\" mp3 192"
    echo ""
    echo "Supported audio formats: mp3, m4a, opus, vorbis, wav"
    echo "Default format: mp3"
    echo "Default quality: best"
    exit 1
fi

URL="$1"
FORMAT="${2:-mp3}"
QUALITY="${3:-best}"

# Validate URL
if [[ ! "$URL" =~ youtube.com|youtu.be ]]; then
    echo "Error: Invalid YouTube URL"
    exit 1
fi

# Set output directory
OUTPUT_DIR="$HOME/Downloads"
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
