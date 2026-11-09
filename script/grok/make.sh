#!/bin/bash
# Grok Imagine demo clip: script/grok/make.sh <male|female> <slug>   (see README.md)
# Env: KEEP_RAW=1 reuses tmp/grok/<figure>/<slug>/raw.mp4 (re-run ffmpeg only).
set -euo pipefail
FIG=$1 SLUG=$2
ROOT=$(cd "$(dirname "$0")/../.." && pwd); ID=$ROOT/script/grok/identity
SRC=$ROOT/public/videos/$FIG/$SLUG.mp4; OUT=$ROOT/public/videos/$FIG/$SLUG
W=$ROOT/tmp/grok/$FIG/$SLUG; mkdir -p "$W"; cd "$W"
LOG=$ROOT/script/grok/log.txt
log() { echo "$(date +%F) $SLUG $FIG $*" >> "$LOG"; }

if [ -z "${KEEP_RAW:-}" ] || [ ! -f raw.mp4 ]; then
  [ -f src.mp4 ] || cp "$SRC" src.mp4   # keep the Mixamo render as the motion source; public/ gets overwritten
  LEN=$(ffprobe -v error -show_entries format=duration -of csv=p=0 src.mp4)
  read -r DUR N <<<"$(python3 -c "import math;l=$LEN;print(min(15,max(2,math.ceil(l))), 2 if l<2.6 else 4)")"
  PROP=$(sed -n 's/^prop: *//p' "$ROOT/config/catalog/motions/$SLUG.yml")
  case $PROP in
    chair) PROPTXT="He or she uses a plain sturdy light-wood stool (no back) standing on the floor; hands and feet rest ON its top surface and never pass through it." ;;
    wall)  PROPTXT="A plain flat cream wall stands behind; the back presses flat against it and never passes through it." ;;
    *)     PROPTXT="" ;;
  esac
  FLOOR=$(ruby -ryaml -e 'e=YAML.load_file(ARGV[0]); e=e.values.first if e.is_a?(Hash); x=e.find{|h| h["slug"]==ARGV[1]}; print x["floor"] ? 1 : ""' "$ROOT/config/catalog/exercises.yml" "$SLUG")
  START=$ID/${FIG}_base.jpg; steps=""; kf=""; i0=0
  if [ -n "$PROP$FLOOR" ]; then  # own start pose (with the prop / on the floor) as loop frame
    ffmpeg -v error -y -i src.mp4 -frames:v 1 src0.png; i0=1
    steps+="1. image_edit images [$ID/${FIG}_base.jpg, $W/src0.png]: photoreal photo of the exact person in image 1 (same clean-shaven face, hair, outfit; take ONLY the body pose from image 2, never its face, beard or clothes), in exactly the body pose and position of image 2 (start of $SLUG). Keep image 1's camera angle, framing, cream cyclorama and light. $PROPTXT Correct anatomy, natural hands. 1:1.
"
    START="result of step 1"
  fi
  for i in $(seq 1 "$N"); do
    t=$(python3 -c "print(round($LEN*$i/($N+1),2))"); to=$(python3 -c "print(round($DUR*$i/($N+1),2))")
    ffmpeg -v error -y -ss "$t" -i src.mp4 -frames:v 1 "src$i.png"
    steps+="$((i+i0)). image_edit images [$ID/${FIG}_base.jpg, $W/src$i.png]: photoreal photo of the exact person in image 1 (same clean-shaven face, hair, outfit; take ONLY the body pose from image 2, never its face, beard or clothes), in exactly the body pose of image 2 ($SLUG). Keep image 1's camera angle, framing, cream cyclorama and light. $PROPTXT Correct anatomy, natural hands. 1:1.
"
    kf+="{image: result of step $((i+i0)), timestamp_s: $to}, "
  done
  steps+="$((N+i0+1)). reference_to_video: aspect_ratio 1:1, resolution_name 720p, duration $DUR, first_frame $START, last_frame $START, keyframes [${kf%, }], images [$ID/$FIG.jpg]. Prompt: 'Real filmed fitness demo of $SLUG. Static locked-off camera, fixed 3/4 angle, no camera movement, no cuts. Same person throughout, hair unchanged. Exactly one prop, which never moves, duplicates or changes shape; camera never flips or mirrors. $PROPTXT Starts in the exact first frame, moves smoothly through the keyframe poses with natural realistic motion and hands, and ends in the exact starting pose.'"
  # ponytail: only image_edit + reference_to_video allowed; no shell for grok, no --always-approve
  grok -p "Run these steps strictly one at a time, in order, never in parallel; wait for each tool result before the next call. Pass the exact absolute file path each image_edit returns (under ~/.grok/sessions) wherever a step says 'result of step N'. Then list each saved output path:
$steps" --tools "image_edit,reference_to_video" > grok.log 2>&1 || { log "FAIL grok exit $? $(tail -c 200 grok.log | tr '\n' ' ')"; exit 1; }
  VID=$(grep -o '/[^ `)]*/videos/[0-9]*\.mp4' grok.log | tail -1 || true)
  [ -n "$VID" ] && [ -f "$VID" ] || { log "FAIL no video: $(tail -c 200 grok.log | tr '\n' ' ')"; exit 1; }
  cp "$VID" raw.mp4
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
