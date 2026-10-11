#!/bin/bash
set -e

echo "India News Hub - Real News Content Renderer"

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

python3 - "$INPUT" <<'PY'
import json
import sys

path = sys.argv[1]

with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

title = str(data.get("title", "")).strip()

if not title:
    raise SystemExit("ERROR: title missing")

scenes = data.get("scenes", [])

if len(scenes) < 4:
    raise SystemExit("ERROR: minimum 4 scenes required")

for i, scene in enumerate(scenes[:4], 1):
    heading = str(scene.get("heading", "")).strip()
    text = str(scene.get("text", "")).strip()

    if not heading or not text:
        raise SystemExit("ERROR: scene data incomplete")

    with open(f"/workspace/scene{i}_heading.txt", "w", encoding="utf-8") as f:
        f.write(heading)

    with open(f"/workspace/scene{i}_text.txt", "w", encoding="utf-8") as f:
        f.write(text)

with open("/workspace/title.txt", "w", encoding="utf-8") as f:
    f.write(title)

print("NEWS CONTENT: VALID")
print("TITLE:", title)
print("SCENES:", len(scenes))
PY

AUDIO_DURATION=$(ffprobe \
  -v error \
  -show_entries format=duration \
  -of default=noprint_wrappers=1:nokey=1 \
  "$VOICE")

if [ -z "$AUDIO_DURATION" ]; then
  echo "ERROR: audio duration not detected"
  exit 1
fi

SCENE_DURATION=$(awk "BEGIN {print $AUDIO_DURATION/4}")

echo "AUDIO DURATION: $AUDIO_DURATION"
echo "SCENE DURATION: $SCENE_DURATION"

create_scene() {
  NUM="$1"
  COLOR="$2"

  ffmpeg -y \
    -f lavfi \
    -i "color=c=$COLOR:s=1280x720:r=30:d=$SCENE_DURATION" \
    -vf "drawtext=text='INDIA NEWS HUB':fontcolor=white:fontsize=48:x=(w-text_w)/2:y=70,drawtext=textfile=/workspace/scene${NUM}_heading.txt:fontcolor=white:fontsize=54:x=(w-text_w)/2:y=250,drawtext=textfile=/workspace/scene${NUM}_text.txt:fontcolor=white:fontsize=28:x=100:y=370:line_spacing=12" \
    -c:v libx264 \
    -pix_fmt yuv420p \
    "/workspace/scene${NUM}.mp4"
}

create_scene 1 0x102A43
create_scene 2 0x243B53
create_scene 3 0x334E68
create_scene 4 0x486581

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
echo "REAL NEWS VIDEO CREATED"
echo "================================"

ls -lh /workspace/output/
