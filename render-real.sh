#!/bin/bash
set -e

INPUT="/workspace/input/news.json"
VOICE="/workspace/input/voice.wav"
OUTPUT="/workspace/output/india-news-hub-real-test.mp4"

mkdir -p /workspace/output /workspace/assets /workspace/scenes

[ -s "$INPUT" ] || { echo "ERROR: news.json missing or empty"; exit 1; }
[ -s "$VOICE" ] || { echo "ERROR: voice.wav missing or empty"; exit 1; }

python3 - "$INPUT" <<'PY'
import json, sys, textwrap, re, os
p=sys.argv[1]
with open(p,encoding='utf-8') as f: d=json.load(f)

title=' '.join(str(d.get('title','')).split()).strip()
if not title: raise SystemExit('ERROR: title missing')
scenes=d.get('scenes') or []
if len(scenes)<4: raise SystemExit('ERROR: minimum 4 scenes required')

def clean(v):
    v=str(v or '')
    v=re.sub(r'\b(HOOK|WHAT HAPPENED|WHY IT MATTERS|WHAT NEXT|SOURCES|CONCLUSION)\s*:\s*','',v,flags=re.I)
    return ' '.join(v.split()).strip()

def wrap(v,w):
    return '\n'.join(textwrap.wrap(clean(v),width=w,break_long_words=False,break_on_hyphens=False))

open('/workspace/title.txt','w',encoding='utf-8').write(wrap(title,44))
for i,s in enumerate(scenes[:4],1):
    h=clean(s.get('heading',''))
    t=clean(s.get('text',''))
    if not t: raise SystemExit(f'ERROR: scene {i} text missing')
    h=re.sub(r'\b(HOOK|WHAT HAPPENED|WHY IT MATTERS|WHAT NEXT|SOURCES|CONCLUSION)\b','',h,flags=re.I).strip() or f'NEWS {i}'
    open(f'/workspace/scene{i}_heading.txt','w',encoding='utf-8').write(wrap(h,32))
    open(f'/workspace/scene{i}_text.txt','w',encoding='utf-8').write(wrap(t,64))

print('NEWS CONTENT: VALID')
print('TITLE:',title)
print('SCENES:',len(scenes))
PY

AUDIO_DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$VOICE")
[ -n "$AUDIO_DURATION" ] || { echo "ERROR: audio duration not detected"; exit 1; }
SCENE_DURATION=$(awk "BEGIN {print $AUDIO_DURATION/4}")

find_asset() {
  for ext in jpg jpeg png webp; do
    if [ -s "/workspace/assets/scene$1.$ext" ]; then echo "/workspace/assets/scene$1.$ext"; return 0; fi
  done
  return 1
}

make_fallback() {
  local n="$1" bg="$2"
  local heading="/workspace/scene${n}_heading.txt"
  local text="/workspace/scene${n}_text.txt"
  ffmpeg -y -f lavfi -i "color=c=$bg:s=1280x720:r=30:d=$SCENE_DURATION" \
    -vf "
      drawgrid=w=80:h=80:t=1:c=white@0.035,
      drawbox=x='mod(t*220\\,1500)-350':y=0:w=350:h=720:color=white@0.045:t=fill,
      drawbox=x=0:y=0:w=1280:h=7:color=0xE63946@0.95:t=fill,
      drawbox=x=0:y=713:w='1280*t/$SCENE_DURATION':h=7:color=white@0.85:t=fill,
      drawbox=x=45:y=105:w=1190:h=3:color=white@0.18:t=fill,
      drawtext=text='INDIA NEWS HUB':fontcolor=white@0.95:fontsize=25:x=48:y=30,
      drawtext=text='NEWS BRIEF':fontcolor=white@0.55:fontsize=18:x=48:y=65,
      drawtext=text='0$n':fontcolor=white@0.12:fontsize=150:x=1030:y=70,
      drawtext=textfile=$heading:fontcolor=white:fontsize=42:x=60:y=155:line_spacing=6:box=1:boxcolor=black@0.25:boxborderw=16,
      drawtext=textfile=$text:fontcolor=white@0.92:fontsize=28:x=60:y=330:line_spacing=12:box=1:boxcolor=black@0.25:boxborderw=18
    " \
    -c:v libx264 -preset veryfast -pix_fmt yuv420p "/workspace/scenes/scene$n.mp4"
}

make_image_scene() {
  local n="$1" img="$2"
  local heading="/workspace/scene${n}_heading.txt"
  local text="/workspace/scene${n}_text.txt"

  # Convert the still image into a real motion shot: slow push-in + lateral drift.
  ffmpeg -y -loop 1 -i "$img" -t "$SCENE_DURATION" \
    -vf "
      scale=1920:1080:force_original_aspect_ratio=increase,
      crop=1920:1080,
      zoompan=z='1.03+0.00065*on':x='80*sin(on/210)':y='55*cos(on/260)':d=1:s=1280x720:fps=30,
      eq=contrast=1.04:saturation=1.06,
      drawbox=x=0:y=0:w=1280:h=720:color=black@0.22:t=fill,
      drawbox=x=0:y=0:w=1280:h=115:color=black@0.52:t=fill,
      drawbox=x=0:y=590:w=1280:h=130:color=black@0.72:t=fill,
      drawbox=x=0:y=0:w=7:h=720:color=0xE63946@0.95:t=fill,
      drawbox=x=7:y=0:w='1273*t/$SCENE_DURATION':h=5:color=white@0.9:t=fill,
      drawtext=text='INDIA NEWS HUB':fontcolor=white@0.96:fontsize=24:x=38:y=27,
      drawtext=text='NEWS BRIEF':fontcolor=white@0.56:fontsize=17:x=38:y=60,
      drawtext=text='0$n':fontcolor=white@0.18:fontsize=90:x=1140:y=22,
      drawtext=textfile=$heading:fontcolor=white:fontsize=35:x=38:y=78:line_spacing=4,
      drawtext=textfile=$text:fontcolor=white@0.96:fontsize=26:x=42:y=615:line_spacing=8:box=1:boxcolor=black@0.25:boxborderw=10
    " \
    -c:v libx264 -preset veryfast -pix_fmt yuv420p "/workspace/scenes/scene$n.mp4"
}

for n in 1 2 3 4; do
  img=$(find_asset "$n" || true)
  if [ -n "$img" ]; then
    echo "SCENE $n: IMAGE $img"
    make_image_scene "$n" "$img"
  else
    echo "SCENE $n: NO IMAGE - PROFESSIONAL GRAPHIC FALLBACK"
    case "$n" in
      1) make_fallback 1 0x0B1F33;;
      2) make_fallback 2 0x12344A;;
      3) make_fallback 3 0x173E55;;
      4) make_fallback 4 0x203F50;;
    esac
  fi
done

printf "file '/workspace/scenes/scene1.mp4'\nfile '/workspace/scenes/scene2.mp4'\nfile '/workspace/scenes/scene3.mp4'\nfile '/workspace/scenes/scene4.mp4'\n" > /workspace/concat.txt

ffmpeg -y -f concat -safe 0 -i /workspace/concat.txt -c copy /workspace/video-only.mp4

ffmpeg -y -i /workspace/video-only.mp4 -i "$VOICE" \
  -map 0:v -map 1:a -c:v copy -c:a aac -b:a 192k -shortest "$OUTPUT"

[ -s "$OUTPUT" ] || { echo "ERROR: final MP4 missing or empty"; exit 1; }
echo "PROFESSIONAL NEWS VIDEO CREATED"
ls -lh "$OUTPUT"
