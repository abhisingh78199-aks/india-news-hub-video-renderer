#!/bin/bash
set -e

echo "India News Hub - Visual News Renderer"

INPUT="/workspace/input/news.json"
VOICE="/workspace/input/voice.wav"
OUTPUT="/workspace/output/india-news-hub-real-test.mp4"
VISUAL_DIR="/workspace/input/visuals"

mkdir -p /workspace/output

if [ ! -s "$INPUT" ]; then
  echo "ERROR: news.json missing or empty"
  exit 1
fi

if [ ! -s "$VOICE" ]; then
  echo "ERROR: voice.wav missing or empty"
  exit 1
fi

if [ ! -d "$VISUAL_DIR" ]; then
  echo "ERROR: visuals directory missing"
  exit 1
fi

python3 - "$INPUT" "$VISUAL_DIR" <<'PY'
import json
import os
import re
import sys
import textwrap

path = sys.argv[1]
visual_dir = sys.argv[2]

with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

title = " ".join(
    str(data.get("title", "")).split()
).strip()

scenes = data.get("scenes", [])
visuals = data.get("visuals", [])

if not title:
    raise SystemExit("ERROR: title missing")

if len(scenes) < 4:
    raise SystemExit(
        "ERROR: minimum 4 scenes required"
    )

if len(visuals) < 4:
    raise SystemExit(
        "ERROR: minimum 4 visual assets required"
    )

def clean(value):
    value = str(value or "")

    value = re.sub(
        r'\b(HOOK|WHAT HAPPENED|WHY IT MATTERS|WHAT NEXT|SOURCES|CONCLUSION)\s*:\s*',
        '',
        value,
        flags=re.I
    )

    return " ".join(value.split()).strip()

def wrap(value, width):
    return "\n".join(
        textwrap.wrap(
            clean(value),
            width=width,
            break_long_words=False,
            break_on_hyphens=False
        )
    )

with open(
    "/workspace/title.txt",
    "w",
    encoding="utf-8"
) as f:
    f.write(
        wrap(title, 48)
    )

for i, scene in enumerate(
    scenes[:4],
    1
):
    heading = clean(
        scene.get("heading", "")
    )

    text = clean(
        scene.get("text", "")
    )

    if not text:
        raise SystemExit(
            f"ERROR: scene {i} text missing"
        )

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

    caption = text[:150].rsplit(
        " ",
        1
    )[0]

    if len(text) > 150:
        caption += "..."

    with open(
        f"/workspace/scene{i}_heading.txt",
        "w",
        encoding="utf-8"
    ) as f:
        f.write(
            wrap(heading, 32)
        )

    with open(
        f"/workspace/scene{i}_caption.txt",
        "w",
        encoding="utf-8"
    ) as f:
        f.write(
            wrap(caption, 58)
        )

for i in range(1, 5):
    filename = os.path.join(
        visual_dir,
        f"scene{i}.jpg"
    )

    if (
        not os.path.isfile(filename)
        or os.path.getsize(filename) == 0
    ):
        raise SystemExit(
            f"ERROR: visual asset missing for scene {i}"
        )

print("VISUAL NEWS CONTENT: VALID")
print("TITLE:", title)
print("SCENES:", len(scenes))
print("VISUALS:", len(visuals))
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

SCENE_DURATION=$(awk \
  "BEGIN {print $AUDIO_DURATION/4}"
)

echo "AUDIO DURATION: $AUDIO_DURATION"
echo "SCENE DURATION: $SCENE_DURATION"

create_scene() {

  NUM="$1"

  IMAGE="$VISUAL_DIR/scene${NUM}.jpg"

  OUTPUT_SCENE="/workspace/scene${NUM}.mp4"

  ffmpeg -y \
    -loop 1 \
    -i "$IMAGE" \
    -t "$SCENE_DURATION" \
    -vf "
      scale=1920:1080:force_original_aspect_ratio=increase,
      crop=1920:1080,
      zoompan=z='min(zoom+0.0008,1.12)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=1280x720:fps=30,
      drawbox=x=0:y=0:w=1280:h=720:color=black@0.10:t=fill,
      drawbox=x=0:y=0:w=1280:h=88:color=black@0.55:t=fill,
      drawbox=x=0:y=535:w=1280:h=185:color=black@0.70:t=fill,
      drawbox=x='mod(t*180\,1500)-180':y=0:w=420:h=720:color=white@0.035:t=fill,
      drawbox=x=0:y=0:w=1280:h=5:color=white@0.80:t=fill,
      drawbox=x=0:y=715:w='1280*t/$SCENE_DURATION':h=5:color=white@0.90:t=fill,

      drawtext=text='INDIA NEWS HUB':
        fontcolor=white@0.92:
        fontsize=22:
        x=45:
        y=25,

      drawtext=text='AI-GENERATED ILLUSTRATIVE VISUAL':
        fontcolor=white@0.60:
        fontsize=17:
        x=45:
        y=58,

      drawtext=text='0$NUM':
        fontcolor=white@0.65:
        fontsize=34:
        x=1190:
        y=25,

      drawtext=textfile=/workspace/title.txt:
        fontcolor=white:
        fontsize=30:
        x=45:
        y=105:
        line_spacing=6,

      drawtext=textfile=/workspace/scene${NUM}_heading.txt:
        fontcolor=white:
        fontsize=34:
        x=55:
        y=555,

      drawtext=textfile=/workspace/scene${NUM}_caption.txt:
        fontcolor=white@0.92:
        fontsize=23:
        x=55:
        y=625:
        line_spacing=8,

      fade=t=in:st=0:d=0.5,
      fade=t=out:st=$(awk "BEGIN {print $SCENE_DURATION-0.5}"):d=0.5
    " \
    -an \
    -c:v libx264 \
    -preset veryfast \
    -pix_fmt yuv420p \
    "$OUTPUT_SCENE"
}

create_scene 1
create_scene 2
create_scene 3
create_scene 4

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
echo "VISUAL NEWS VIDEO CREATED"
echo "================================"

ls -lh "$OUTPUT"
