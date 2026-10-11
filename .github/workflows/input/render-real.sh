#!/bin/bash
set -e

echo "India News Hub - Real Input Renderer"

INPUT="/workspace/input/news.json"
OUTPUT="/workspace/output/india-news-hub-real-test.mp4"

mkdir -p /workspace/output

if [ ! -f "$INPUT" ]; then
  echo "ERROR: news.json not found"
  exit 1
fi

TITLE=$(python3 -c "import json; print(json.load(open('$INPUT'))['title'])")
SCRIPT=$(python3 -c "import json; print(json.load(open('$INPUT'))['script'])")

echo "TITLE: $TITLE"
echo "SCRIPT LOADED: YES"

ffmpeg -y \
  -f lavfi -i "color=c=0x102A43:s=1280x720:r=30:d=5" \
  -vf "drawtext=text='INDIA NEWS HUB':fontcolor=white:fontsize=64:x=(w-text_w)/2:y=230,drawtext=text='$TITLE':fontcolor=white:fontsize=32:x=(w-text_w)/2:y=350" \
  -c:v libx264 -pix_fmt yuv420p \
  /workspace/scene1.mp4

ffmpeg -y \
  -f lavfi -i "color=c=0x243B53:s=1280x720:r=30:d=5" \
  -vf "drawtext=text='WHAT HAPPENED?':fontcolor=white:fontsize=58:x=(w-text_w)/2:y=280" \
  -c:v libx264 -pix_fmt yuv420p \
  /workspace/scene2.mp4

ffmpeg -y \
  -f lavfi -i "color=c=0x334E68:s=1280x720:r=30:d=5" \
  -vf "drawtext=text='ORIGINAL NEWS SCRIPT':fontcolor=white:fontsize=52:x=(w-text_w)/2:y=280" \
  -c:v libx264 -pix_fmt yuv420p \
  /workspace/scene3.mp4

ffmpeg -y \
  -f lavfi -i "color=c=0x486581:s=1280x720:r=30:d=5" \
  -vf "drawtext=text='HUMAN REVIEW REQUIRED':fontcolor=white:fontsize=44:x=(w-text_w)/2:y=280" \
  -c:v libx264 -pix_fmt yuv420p \
  /workspace/scene4.mp4

printf "file '/workspace/scene1.mp4'\nfile '/workspace/scene2.mp4'\nfile '/workspace/scene3.mp4'\nfile '/workspace/scene4.mp4'\n" > /workspace/concat.txt

ffmpeg -y \
  -f concat \
  -safe 0 \
  -i /workspace/concat.txt \
  -c copy \
  "$OUTPUT"

echo "================================"
echo "REAL INPUT MP4 CREATED"
echo "================================"

ls -lh /workspace/output/
