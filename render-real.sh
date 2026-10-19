#!/bin/bash
set -e

echo "India News Hub - Animated News Renderer"

INPUT="/workspace/input/news.json"
VOICE="/workspace/input/voice.wav"
OUTPUT="/workspace/output/india-news-hub-real-test.mp4"

mkdir -p /workspace/output

if [ ! -s "$INPUT" ]; then
  echo "ERROR: news.json missing or empty"
  exit 1
fi

if [ ! -s "$VOICE" ]; then
  echo "ERROR: voice.wav missing or empty"
  exit 1
fi

python3 - "$INPUT" <<'PY'
import json
import sys
import textwrap
import re

path = sys.argv[1]

with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

title = " ".join(str(data.get("title", "")).split()).strip()

if not title:
    raise SystemExit("ERROR: title missing")

scenes = data.get("scenes", [])

if len(scenes) < 4:
    raise SystemExit("ERROR: minimum 4 scenes required")

def clean(value):
    value = str(value or "")
    value = re.sub(
        r'\b(HOOK|WHAT HAPPENED|WHY IT MATTERS|WHAT NEXT|SOURCES|CONCLUSION)\s*:\s*',
        '',
        value,
        flags=re.I
    )
    value = " ".join(value.split())
    return value.strip()

def wrap(value, width):
    return "\n".join(
        textwrap.wrap(
            clean(value),
            width=width,
            break_long_words=False,
            break_on_hyphens=False
        )
    )

with open("/workspace/title.txt", "w", encoding="utf-8") as f:
    f.write(wrap(title, 38))

for i, scene in enumerate(scenes[:4], 1):

    heading = clean(scene.get("heading", ""))
    text = clean(scene.get("text", ""))

    if not text:
        raise SystemExit(f"ERROR: scene {i} text missing")

    if not heading:
        heading = f"NEWS {i}"

    heading = re.sub(
        r'\b(HOOK|WHAT HAPPENED|WHY IT MATTERS|WHAT NEXT|SOURCES|CONCLUSION)\b',
        '',
        heading,
        flags=re.I
    ).strip()

    if not heading:
        heading = f"NEWS {i}"

    with open(
        f"/workspace/scene{i}_heading.txt",
        "w",
        encoding="utf-8"
    ) as f:
        f.write(wrap(heading, 30))

    with open(
        f"/workspace/scene{i}_text.txt",
        "w",
        encoding="utf-8"
    ) as f:
        f.write(wrap(text, 62))

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
  BG="$2"

  ffmpeg -y \
    -f lavfi \
    -i "color=c=$BG:s=1280x720:r=30:d=$SCENE_DURATION" \
    -vf "
      drawbox=x='mod(t*180\,1500)-180':y=0:w=420:h=720:color=white@0.035:t=fill,
      drawbox=x='1280-mod(t*120\,1500)':y=0:w=280:h=720:color=white@0.025:t=fill,
      drawbox=x=0:y=0:w=1280:h=8:color=white@0.75:t=fill,
      drawbox=x=0:y=712:w='1280*t/$SCENE_DURATION':h=8:color=white@0.9:t=fill,

      drawtext=text='INDIA NEWS HUB':
        fontcolor=white@0.78:
        fontsize=24:
        x=55:
        y=35,

      drawtext=text='0$NUM':
        fontcolor=white@0.28:
        fontsize=110:
        x=1120:
        y=55,

      drawtext=textfile=/workspace/title.txt:
        fontcolor=white:
        fontsize=42:
        x=70:
        y=105:
        line_spacing=8:
        box=1:
        boxcolor=black@0.22:
        boxborderw=14,

      drawtext=textfile=/workspace/scene${NUM}_heading.txt:
        fontcolor=white:
        fontsize=38:
        x=70:
        y=275:
        box=1:
        boxcolor=black@0.32:
        boxborderw=14,

      drawtext=textfile=/workspace/scene${NUM}_text.txt:
        fontcolor=white@0.94:
        fontsize=30:
        x=70:
        y=365:
        line_spacing=15:
        box=1:
        boxcolor=black@0.30:
        boxborderw=18
    " \
    -c:v libx264 \
    -preset veryfast \
    -pix_fmt yuv420p \
    "/workspace/scene${NUM}.mp4"
}

create_scene 1 0x102A43
create_scene 2 0x173F5F
create_scene 3 0x24566F
create_scene 4 0x315C72

printf \
"file '/workspace/scene1.mp4'\nfile '/workspace/scene2.mp4'\nfile '/workspace/scene3.mp4'\nfile '/workspace/scene4.mp4'\n" \
> /workspace/concat.txt

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

if [ ! -s "$OUTPUT" ]; then
  echo "ERROR: final MP4 missing or empty"
  exit 1
fi

echo "================================"
echo "ANIMATED NEWS VIDEO CREATED"
echo "================================"

ls -lh /workspace/output/
