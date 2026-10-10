#!/bin/bash
set -e

echo "India News Hub - Multi Scene MP4 Renderer"

mkdir -p /workspace/output

# Scene 1 - Hook
ffmpeg -y \
  -f lavfi -i "color=c=0x102A43:s=1280x720:r=30:d=5" \
  -vf "drawtext=text='INDIA NEWS HUB':fontcolor=white:fontsize=64:x=(w-text_w)/2:y=260,drawtext=text='IMPORTANT NEWS':fontcolor=white:fontsize=36:x=(w-text_w)/2:y=360" \
  -c:v libx264 -pix_fmt yuv420p \
  /workspace/scene1.mp4

# Scene 2 - What happened
ffmpeg -y \
  -f lavfi -i "color=c=0x243B53:s=1280x720:r=30:d=5" \
  -vf "drawtext=text='WHAT HAPPENED?':fontcolor=white:fontsize=58:x=(w-text_w)/2:y=280,drawtext=text='Verified information and key facts':fontcolor=white:fontsize=32:x=(w-text_w)/2:y=370" \
  -c:v libx264 -pix_fmt yuv420p \
  /workspace/scene2.mp4

# Scene 3 - Impact
ffmpeg -y \
  -f lavfi -i "color=c=0x334E68:s=1280x720:r=30:d=5" \
  -vf "drawtext=text='WHY IT MATTERS':fontcolor=white:fontsize=58:x=(w-text_w)/2:y=280,drawtext=text='Clear explanation for viewers':fontcolor=white:fontsize=32:x=(w-text_w)/2:y=370" \
  -c:v libx264 -pix_fmt yuv420p \
  /workspace/scene3.mp4

# Scene 4 - What next
ffmpeg -y \
  -f lavfi -i "color=c=0x486581:s=1280x720:r=30:d=5" \
  -vf "drawtext=text='WHAT NEXT?':fontcolor=white:fontsize=58:x=(w-text_w)/2:y=280,drawtext=text='Follow verified developments':fontcolor=white:fontsize=32:x=(w-text_w)/2:y=370" \
  -c:v libx264 -pix_fmt yuv420p \
  /workspace/scene4.mp4

# Combine scenes
printf "file '/workspace/scene1.mp4'\nfile '/workspace/scene2.mp4'\nfile '/workspace/scene3.mp4'\nfile '/workspace/scene4.mp4'\n" > /workspace/concat.txt

ffmpeg -y \
  -f concat \
  -safe 0 \
  -i /workspace/concat.txt \
  -c copy \
  /workspace/output/india-news-hub-multiscene-test.mp4

echo "================================"
echo "MULTI-SCENE MP4 CREATED"
echo "================================"

ls -lh /workspace/output/
