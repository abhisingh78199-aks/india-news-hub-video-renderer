#!/bin/bash
set -e

echo "India News Hub - MP4 Renderer"
echo "Checking FFmpeg..."

ffmpeg -version | head -n 1

mkdir -p /workspace/output

echo "Creating test news video..."

ffmpeg -y \
  -f lavfi -i "color=c=0x102A43:s=1280x720:r=30:d=15" \
  -f lavfi -i "sine=frequency=440:duration=15" \
  -vf "drawtext=text='INDIA NEWS HUB':fontcolor=white:fontsize=64:x=(w-text_w)/2:y=260,drawtext=text='Important News - Clear Explanations':fontcolor=white:fontsize=32:x=(w-text_w)/2:y=350" \
  -c:v libx264 \
  -preset veryfast \
  -pix_fmt yuv420p \
  -c:a aac \
  -b:a 128k \
  -shortest \
  /workspace/output/india-news-hub-test.mp4

echo "MP4 created successfully."

ls -lh /workspace/output/

echo "Renderer completed."
