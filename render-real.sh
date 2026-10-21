#!/bin/bash
set -e

INPUT="/workspace/input/news.json"
VOICE="/workspace/input/voice.wav"
OUTPUT="/workspace/output/india-news-hub-real-test.mp4"

mkdir -p /workspace/output /workspace/assets /workspace/scenes

[ -s "$INPUT" ] || { echo "ERROR: news.json missing or empty"; exit 1; }
[ -s "$VOICE" ] || { echo "ERROR: voice.wav missing or empty"; exit 1; }

python3 - "$INPUT" <<'PY'
import json, sys, textwrap, re

p=sys.argv[1]
with open(p,encoding="utf-8") as f:
    d=json.load(f)

title=" ".join(str(d.get("title","")).split()).strip()
if not title:
    raise SystemExit("ERROR: title missing")

scenes=d.get("scenes") or []
if len(scenes) < 4:
    raise SystemExit("ERROR: minimum 4 scenes required")

def clean(v):
    v=str(v or "")
    v=re.sub(
        r'\b(HOOK|WHAT HAPPENED|WHY IT MATTERS|WHAT NEXT|SOURCES|CONCLUSION)\s*:\s*',
        '',
        v,
        flags=re.I
    )
    return " ".join(v.split()).strip()

def wrap(v,w):
    return "\n".join(textwrap.wrap(
        clean(v),
        width=w,
        break_long_words=False,
        break_on_hyphens=False
    ))

open("/workspace/title.txt","w",encoding="utf-8").write(wrap(title,42))

for i,s in enumerate(scenes[:4],1):
    heading=clean(s.get("heading",""))
    text=clean(s.get("text",""))

    if not text:
        raise SystemExit(f"ERROR: scene {i} text missing")

    heading=re.sub(
        r'\b(HOOK|WHAT HAPPENED|WHY IT MATTERS|WHAT NEXT|SOURCES|CONCLUSION)\b',
        '',
        heading,
        flags=re.I
    ).strip() or f"NEWS {i}"

    open(f"/workspace/scene{i}_heading.txt","w",encoding="utf-8").write(wrap(heading,30))
    open(f"/workspace/scene{i}_text.txt","w",encoding="utf-8").write(wrap(text,64))

print("NEWS CONTENT: VALID")
print("SCENES:",len(scenes))
PY

AUDIO_DURATION=$(ffprobe -v error -show_entries format=duration \
  -of default=noprint_wrappers=1:nokey=1 "$VOICE")

[ -n "$AUDIO_DURATION" ] || {
  echo "ERROR: audio duration not detected"
  exit 1
}

SCENE_DURATION=$(awk "BEGIN {print $AUDIO_DURATION/4}")
FADE_OUT=$(awk "BEGIN {x=$SCENE_DURATION-0.45; if(x<0)x=0; print x}")

echo "AUDIO DURATION: $AUDIO_DURATION"
echo "SCENE DURATION: $SCENE_DURATION"

find_asset() {
  for ext in jpg jpeg png webp; do
    if [ -s "/workspace/input/assets/scene$1.$ext" ]; then
      echo "/workspace/input/assets/scene$1.$ext"
      return 0
    fi
  done
  return 1
}

for n in 1 2 3 4; do
  img=$(find_asset "$n" || true)

  if [ -z "$img" ]; then
    echo "ERROR: Scene $n visual asset missing."
    echo "NO FALLBACK GRAPHIC WILL BE USED."
    exit 1
  fi

  echo "SCENE $n VISUAL VERIFIED: $img"
done

make_scene() {
  local n="$1"
  local img="$2"
  local heading="/workspace/scene${n}_heading.txt"
  local text="/workspace/scene${n}_text.txt"

  case "$n" in
    1) MOTION="1.02+0.00075*on"; X="70*sin(on/230)"; Y="35*cos(on/270)";;
    2) MOTION="1.10-0.00055*on"; X="70*cos(on/250)"; Y="35*sin(on/220)";;
    3) MOTION="1.02+0.00060*on"; X="85*sin(on/260)"; Y="45*cos(on/210)";;
    4) MOTION="1.10-0.00050*on"; X="80*cos(on/230)"; Y="40*sin(on/250)";;
  esac

  ffmpeg -y \
    -loop 1 -i "$img" \
    -t "$SCENE_DURATION" \
    -vf "
      scale=1920:1080:force_original_aspect_ratio=increase,
      crop=1920:1080,
      zoompan=z='$MOTION':x='$X':y='$Y':d=1:s=1280x720:fps=30,
      eq=contrast=1.05:saturation=1.10,
      fade=t=in:st=0:d=0.35,
      fade=t=out:st=$FADE_OUT:d=0.45,

      drawbox=x=0:y=0:w=1280:h=720:color=black@0.12:t=fill,

      drawbox=x=0:y=0:w=1280:h=92:color=black@0.68:t=fill,
      drawbox=x=0:y=0:w=8:h=720:color=0xE63946@0.96:t=fill,

      drawbox=x=0:y=560:w=1280:h=160:color=black@0.78:t=fill,
      drawbox=x=0:y=560:w=1280:h=4:color=0xE63946@0.95:t=fill,

      drawbox=x=8:y=0:w='1272*t/$SCENE_DURATION':h=4:color=white@0.90:t=fill,

      drawtext=text='INDIA NEWS HUB':fontcolor=white@0.98:fontsize=25:x=36:y=20,
      drawtext=text='NEWS BRIEF':fontcolor=white@0.60:fontsize=15:x=37:y=54,
      drawtext=text='SCENE 0$n':fontcolor=white@0.28:fontsize=24:x=1120:y=32,

      drawtext=textfile=$heading:fontcolor=white:fontsize=34:
      x=38:y=105:line_spacing=5:
      shadowcolor=black@0.75:shadowx=2:shadowy=2,

      drawtext=textfile=$text:fontcolor=white@0.96:fontsize=23:
      x=42:y=585:line_spacing=7:
      shadowcolor=black@0.80:shadowx=2:shadowy=2
    " \
    -c:v libx264 \
    -preset veryfast \
    -pix_fmt yuv420p \
    "/workspace/scenes/scene$n.mp4"
}

for n in 1 2 3 4; do
  img=$(find_asset "$n")
  echo "RENDERING SCENE $n"
  make_scene "$n" "$img"
done

# Join the four animated scenes with clean broadcast-style transitions.
# Audio timeline remains unchanged because the voice is added after the visual render.

ffmpeg -y \
  -i /workspace/scenes/scene1.mp4 \
  -i /workspace/scenes/scene2.mp4 \
  -i /workspace/scenes/scene3.mp4 \
  -i /workspace/scenes/scene4.mp4 \
  -filter_complex "
    [0:v][1:v]xfade=transition=fade:duration=0.35:offset=$(awk "BEGIN {print $SCENE_DURATION-0.35}")[v1];
    [v1][2:v]xfade=transition=fade:duration=0.35:offset=$(awk "BEGIN {print ($SCENE_DURATION*2)-0.35}")[v2];
    [v2][3:v]xfade=transition=fade:duration=0.35:offset=$(awk "BEGIN {print ($SCENE_DURATION*3)-0.35}") [v]
  " \
  -map "[v]" \
  -c:v libx264 \
  -preset veryfast \
  -pix_fmt yuv420p \
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

[ -s "$OUTPUT" ] || {
  echo "ERROR: final MP4 missing or empty"
  exit 1
}

echo "PROFESSIONAL NEWS VIDEO CREATED"
ls -lh "$OUTPUT"
