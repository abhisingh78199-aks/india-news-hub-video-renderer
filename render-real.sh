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

def wrap(v,w): return '\n'.join(textwrap.wrap(clean(v),width=w,break_long_words=False,break_on_hyphens=False))
open('/workspace/title.txt','w',encoding='utf-8').write(wrap(title,42))
for i,s in enumerate(scenes[:4],1):
    h=clean(s.get('heading',''))
    t=clean(s.get('text',''))
    if not t: raise SystemExit(f'ERROR: scene {i} text missing')
    h=re.sub(r'\b(HOOK|WHAT HAPPENED|WHY IT MATTERS|WHAT NEXT|SOURCES|CONCLUSION)\b','',h,flags=re.I).strip() or f'NEWS {i}'
    open(f'/workspace/scene{i}_heading.txt','w',encoding='utf-8').write(wrap(h,30))
    open(f'/workspace/scene{i}_text.txt','w',encoding='utf-8').write(wrap(t,58))
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
  ffmpeg -y -f lavfi -i "color=c=$bg:s=1280x720:r=30:d=$SCENE_DURATION" \
    -vf "geq=r='20+25*sin(X/90+T)':g='35+25*sin(Y/110+T*0.8)':b='55+35*sin((X+Y)/150+T*0.6)'" \
    -c:v libx264 -preset veryfast -pix_fmt yuv420p "/workspace/scenes/scene$n.mp4"
}

make_image_scene() {
  local n="$1" img="$2" duration="$SCENE_DURATION"
  ffmpeg -y -loop 1 -i "$img" -t "$duration" -vf "
    scale=1600:900:force_original_aspect_ratio=increase,
    crop=1600:900,
    zoompan=z='min(zoom+0.0007,1.12)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=1280x720:fps=30,
    drawbox=x=0:y=0:w=1280:h=720:color=black@0.16:t=fill,
    drawbox=x=0:y=0:w=1280:h=720:color=black@0.30:t=fill,
    drawbox=x=0:y=0:w=1280:h=110:color=black@0.46:t=fill,
    drawbox=x=0:y=650:w=1280:h=70:color=black@0.62:t=fill,
    drawbox=x=0:y=0:w=8:h=720:color=0xE63946@0.9:t=fill,
    drawbox=x=8:y=0:w='1272*t/$duration':h=5:color=white@0.85:t=fill,
    drawtext=text='INDIA NEWS HUB':fontcolor=white@0.9:fontsize=23:x=38:y=25,
    drawtext=text='LIVE NEWS BRIEF':fontcolor=white@0.58:fontsize=18:x=38:y=57,
    drawtext=textfile=/workspace/title.txt:fontcolor=white:fontsize=31:x=38:y=80:line_spacing=4,
    drawtext=text='SCENE $n / 04':fontcolor=white@0.78:fontsize=19:x=1080:y=27,
    drawtext=textfile=/workspace/scene${n}_heading.txt:fontcolor=white:fontsize=35:x=45:y=520:box=1:boxcolor=black@0.38:boxborderw=12,
    drawtext=textfile=/workspace/scene${n}_text.txt:fontcolor=white@0.94:fontsize=25:x=45:y=575:line_spacing=8:box=1:boxcolor=black@0.42:boxborderw=12
  " -c:v libx264 -preset veryfast -pix_fmt yuv420p "/workspace/scenes/scene$n.mp4"
}

for n in 1 2 3 4; do
  img=$(find_asset "$n" || true)
  if [ -n "$img" ]; then
    make_image_scene "$n" "$img"
  else
    case "$n" in
      1) make_fallback 1 0x0B1F33;;
      2) make_fallback 2 0x12344A;;
      3) make_fallback 3 0x1A465C;;
      4) make_fallback 4 0x254F64;;
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
