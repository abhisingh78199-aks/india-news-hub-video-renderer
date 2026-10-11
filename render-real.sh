#!/bin/bash
set -e

echo "India News Hub - Final Audio Video Renderer"

INPUT="/workspace/input/news.json"
VOICE="/workspace/input/voice.wav"
OUTPUT="/workspace/output/india-news-hub-real-test.mp4"

mkdir -p /workspace/output

if [ ! -f "$INPUT" ]; then
  echo "ERROR: news.json not found"
  exit 1
fi

if [ ! -f "$VOICE" ]; then
  echo "ERROR: voice.wav not found"
  exit 1
fi

echo "news.json found."
echo "voice.wav found."

TITLE=$(grep -o '"title"[[:space:]]*:[[:space:]]*"[^"]*"' "$INPUT" | head -n 1 | sed 's/.*:[[:space:]]*"//;s/"$//')

if [ -z "$TITLE" ]; then
  echo "ERROR: title not found"
  exit 1
fi

printf '%s' "$TITLE" > /workspace/title.txt

AUDIO_DURATION=$(ffprobe \
  -v error \
  -show_entries format=duration \
  -of default=noprint_wrappers=1:nokey=1 \
  "$VOICE")

if [ -z "$AUDIO_DURATION" ]; then
  echo "ERROR: audio duration not detected"
  exit 1
fi

echo "AUDIO DURATION: $AUDIO_DURATION seconds"

SCENE_DURATION=$(awk "BEGIN {print $AUDIO_DURATION/4}")

echo "SCENE DURATION: $SCENE_DURATION seconds"

ffmpeg -y \
  -f lavfi -i "color=c=0x102A43:s=1280x720:r=30:d=$SCENE_DURATION" \
  -vf "drawtext=text='INDIA NEWS HUB':fontcolor=white:fontsize=64:x=(w-text_w)/2:y=230,drawtext=textfile=/workspace/title.txt:fontcolor=white:fontsize=32:x=(w-text_w)/2:y=350" \
  -c:v libx264 -pix_fmt yuv420p \
  /workspace/scene1.mp4

ffmpeg -y \
  -f lavfi -i "color=c=0x243B53:s=1280x720:r=30:d=$SCENE_DURATION" \
  -vf "drawtext=text='WHAT HAPPENED?':fontcolor=white:fontsize=58:x=(w-text_w)/2:y=280" \
  -c:v libx264 -pix_fmt yuv420p \
  /workspace/scene2.mp4

ffmpeg -y \
  -f lavfi -i "color=c=0x334E68:s=1280x720:r=30:d=$SCENE_DURATION" \
  -vf "drawtext=text='ORIGINAL NEWS SCRIPT':fontcolor=white:fontsize=52:x=(w-text_w)/2:y=280" \
  -c:v libx264 -pix_fmt yuv420p \
  /workspace/scene3.mp4

ffmpeg -y \
  -f lavfi -i "color=c=0x486581:s=1280x720:r=30:d=$SCENE_DURATION" \
  -vf "drawtext=text='HUMAN REVIEW REQUIRED':fontcolor=white:fontsize=44:x=(w-text_w)/2:y=280" \
  -c:v libx264 -pix_fmt yuv420p \
  /workspace/scene4.mp4

printf "file '/workspace/scene1.mp4'\nfile '/workspace/scene2.mp4'\nfile '/workspace/scene3.mp4'\nfile '/workspace/scene4.mp4'\n" > /workspace/concat.txt

ffmpeg -y \
  -f concat \
  -safe 0 \
  -i /workspace/concat.txt \
  -c copy \
  /workspace/video-only.mp4

ffmpeg -y \
  -i /workspace/video-only.mp4 \
  -i "$VOICE" \
  -map 0:v \
  -map 1:a \
  -c:v copy \
  -c:a aac \
  -b:a 192k \
  -shortest \
  "$OUTPUT"

echo "================================"
echo "FINAL AUDIO MP4 CREATED"
echo "================================"

ls -lh /workspace/output/
