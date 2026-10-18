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
import textwrap

path = sys.argv[1]

with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

title = str(data.get("title", "")).strip()

if not title:
    raise SystemExit("ERROR: title missing")

scenes = data.get("scenes", [])

if len(scenes) < 4:
    raise SystemExit("ERROR: minimum 4 scenes required")

generic_headings = {
    "what happened?",
    "key details",
    "why it matters",
    "what next?",
    "what happened",
    "key details",
    "why it matters",
    "what next"
}

def clean_text(value):
    value = str(value or "").strip()
    value = " ".join(value.split())
    return value

def wrap_text(value, width):
    value = clean_text(value)
    return "\n".join(
        textwrap.wrap(
            value,
            width=width,
            break_long_words=False,
            break_on_hyphens=False
        )
    )

wrapped_title = wrap_text(title, 42)

with open("/workspace/title.txt", "w", encoding="utf-8") as f:
    f.write(wrapped_title)

for i, scene in enumerate(scenes[:4], 1):

    heading = clean_text(scene.get("heading", ""))
    text = clean_text(scene.get("text", ""))

    if not text:
        raise SystemExit(
            f"ERROR: scene {i} text missing"
        )

    heading_lower = heading.lower()

    if not heading or heading_lower in generic_headings:
        heading = f"NEWS UPDATE {i}"

    heading = wrap_text(heading, 34)
    text = wrap_text(text, 68)

    with open(
        f"/workspace/scene{i}_heading.txt",
        "w",
        encoding="utf-8"
    ) as f:
        f.write(heading)

    with open(
        f"/workspace/scene{i}_text.txt",
        "w",
        encoding="utf-8"
    ) as f:
        f.write(text)

print("NEWS CONTENT: VALID")
print("TITLE:", title)
print("SCENES:", len(scenes))

for i, scene in enumerate(scenes[:4], 1):
    print(
        f"SCENE {i}:",
        clean_text(scene.get("text", ""))[:250]
    )
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
    -vf "drawtext=textfile=/workspace/title.txt:fontcolor=white:fontsize=48:x=(w-text_w)/2:y=55:box=1:boxcolor=black@0.35:boxborderw=18,drawtext=textfile=/workspace/scene${NUM}_heading.txt:fontcolor=white:fontsize=46:x=(w-text_w)/2:y=235:box=1:boxcolor=black@0.30:boxborderw=16,drawtext=textfile=/workspace/scene${NUM}_text.txt:fontcolor=white:fontsize=30:x=90:y=370:line_spacing=14:box=1:boxcolor=black@0.28:boxborderw=20" \
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
