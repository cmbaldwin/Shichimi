#!/bin/bash
# Grok Imagine demo clip: script/grok/make.sh <male|female> <slug>   (see README.md)
# Env: KEEP_RAW=1 reuses tmp/grok/<figure>/<slug>/raw.mp4 (re-run ffmpeg only).
set -euo pipefail
FIG=$1 SLUG=$2
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
SRC=$ROOT/public/videos/$FIG/$SLUG.mp4; OUT=$ROOT/public/videos/$FIG/$SLUG
W=$ROOT/tmp/grok/$FIG/$SLUG; mkdir -p "$W"; cd "$W"
LOG=$ROOT/script/grok/log.txt
log() { echo "$(date +%F) $SLUG $FIG $*" >> "$LOG"; }

if [ -z "${KEEP_RAW:-}" ] || [ ! -f raw.mp4 ]; then
  [ -f src.mp4 ] || cp "$SRC" src.mp4   # keep the Mixamo render as the motion source; public/ gets overwritten
  # Direct Imagine API. The grok CLI accepts the video then loses the status poll.
  set +e
  PYTHONUNBUFFERED=1 python3 "$ROOT/script/grok/imagine.py" "$FIG" "$SLUG" > grok.log 2>&1
  code=$?
  set -e
  if [ "$code" -ne 0 ]; then
    log "FAIL imagine exit $code $(tail -c 240 grok.log | tr '\n' ' ')"
    exit "$code"
  fi
  [ -f raw.mp4 ] || { log "FAIL no raw.mp4 $(tail -c 200 grok.log | tr '\n' ' ')"; exit 1; }
fi

# 3-frame seam crossfade: play [d..T] fading into [0..d]; the loop restarts at d.
read -r T FPS <<<"$(ffprobe -v error -select_streams v -show_entries format=duration:stream=r_frame_rate -of csv=p=0 raw.mp4 | tr '\n' ' ' | awk '{split($1,a,"/"); print $2, a[1]/a[2]}')"
read -r D O <<<"$(python3 -c "d=3/$FPS;print(d,$T-2*d)")"
for crf in 28 32 36; do
  ffmpeg -v error -y -i raw.mp4 -filter_complex "[0:v]trim=start=$D,setpts=PTS-STARTPTS[a];[0:v]trim=end=$D,setpts=PTS-STARTPTS[b];[a][b]xfade=transition=fade:duration=$D:offset=$O,scale='min(720,iw)':-2,format=yuv420p" \
    -an -c:v libx264 -crf $crf -preset slow -movflags +faststart "$OUT.mp4"
  [ "$(stat -f%z "$OUT.mp4")" -lt 400000 ] && break
done
ffmpeg -v error -y -i "$OUT.mp4" -frames:v 1 poster.png && cwebp -quiet -q 80 poster.png -o "$OUT.webp"
ffmpeg -v error -y -i "$OUT.mp4" -vf "select='not(mod(n\,6))',scale=160:-1,tile=9x1" -frames:v 1 strip.png
log "OK $(stat -f%z "$OUT.mp4")B"
