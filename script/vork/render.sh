#!/bin/sh
# Render exercise loop videos with Vork. Needs: bin/rails s -p 3117 running (development), vork, ffmpeg, Chrome.
# Usage: script/vork/render.sh squat push_up ...   (OUT=dir to keep work files elsewhere; PROFILE=std/draft for speed)
set -eu
cd "$(dirname "$0")/../.."
OUT=${OUT:-tmp/vork}
PROFILE=${PROFILE:-std/final}
PORT=${PORT:-3117}
VORK=${VORK:-$HOME/.local/bin/vork}
CHROME=${CHROME:-"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"}
mkdir -p "$OUT" public/videos
for slug in "$@"; do
  # 1. browser: pose one loop with the app's rig → tmp/exports/<slug>.glb + .json
  # The page POSTs the files; check they were written (dump-dom can return before the status text updates).
  rm -f "tmp/exports/$slug.glb" "tmp/exports/$slug.json"
  "$CHROME" --headless=new --use-angle=swiftshader --enable-unsafe-swiftshader --virtual-time-budget=300000 \
    --dump-dom "http://localhost:$PORT/dev/export/$slug" >/dev/null 2>&1 || true
  [ -s "tmp/exports/$slug.glb" ] && [ -s "tmp/exports/$slug.json" ] \
    || { echo "export failed for $slug (see log/development.log)" >&2; exit 1; }
  # 2. scene + frames
  ruby script/vork/scene.rb "$slug" "$OUT"
  frames=$(ruby -rjson -e "puts JSON.parse(File.read('tmp/exports/$slug.json'))['frames']")
  (cd "$OUT" && "$VORK" render "$slug.json" --out "$slug" --frame-start 0 --frame-end $((frames - 1)) --profile "$PROFILE" --set samples=${SAMPLES:-64})
  # 3. encode: H.264, faststart, plus a WebP poster from frame 0
  ffmpeg -v error -y -framerate 30 -i "$OUT/$slug/%06d.png" -c:v libx264 -preset slow -crf ${CRF:-23} \
    -pix_fmt yuv420p -movflags +faststart -an "public/videos/$slug.mp4"
  cwebp -quiet -q 80 "$OUT/$slug/000000.png" -o "public/videos/$slug.webp"
  ls -l "public/videos/$slug.mp4" "public/videos/$slug.webp"
done
