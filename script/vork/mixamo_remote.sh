#!/bin/sh
# Runs on Escalante (via mixamo.sh render): renders every tmp/vorkm/<who>/<slug>.json that has no newer video yet.
# One render at a time, nice 19 (no taskpolicy -b: ~5x slower). Log: log/mixamo.log.
set -u
export PATH=/opt/homebrew/bin:$HOME/.local/bin:$PATH
cd ~/Dev/shichimi
echo "== $(date) start"
# args: optional who/slug filters (e.g. adam/squat); default all
if [ $# -gt 0 ]; then scenes=$(for a in "$@"; do ls "tmp/vorkm/$a.json" 2>/dev/null; done); else scenes=$(ls tmp/vorkm/*/*.json); fi
for scene in $scenes; do
  who=$(basename "$(dirname "$scene")"); slug=$(basename "$scene" .json)
  case $who in adam) dir=male ;; jody) dir=female ;; *) continue ;; esac
  out=public/videos/$dir/$slug.mp4
  [ "$out" -nt "$scene" ] && continue
  mkdir -p "public/videos/$dir"; t=$(date +%s)
  frames=$(ruby -rjson -e "puts (JSON.parse(File.read('$scene'))['render']['duration'] * 30).round")
  rm -rf "tmp/vorkm/$who/$slug"
  (cd "tmp/vorkm/$who" && nice -n 19 vork render "$slug.json" --out "$slug" --frame-start 0 --frame-end $((frames - 1)) \
     --profile std/final --set samples=${SAMPLES:-64} >/dev/null) || { echo "FAIL $who $slug"; continue; }
  nice -n 19 ffmpeg -v error -y -framerate 30 -i "tmp/vorkm/$who/$slug/%06d.png" -c:v libx264 -preset slow -crf ${CRF:-24} \
    -pix_fmt yuv420p -movflags +faststart -an "$out"
  cwebp -quiet -q 80 "tmp/vorkm/$who/$slug/000000.png" -o "public/videos/$dir/$slug.webp"
  echo "OK $who $slug $frames frames $(( $(date +%s) - t ))s $(stat -f %z "$out") bytes"
done
echo "== $(date) done"
