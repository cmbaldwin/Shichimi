#!/bin/sh
# Contact sheet of a built Mixamo scene (8 evenly spaced previs frames, 4x2) for reviewing form, feet, hands, loop.
# usage: script/vork/sheet.sh adam squat [out.png]
set -eu
cd "$(dirname "$0")/../../tmp/vorkm/$1"
out=${3:-$PWD/$2.sheet.png}; d=$(mktemp -d)
dur=$(ruby -rjson -e "puts JSON.parse(File.read('$2.json'))['render']['duration']")
for i in 0 1 2 3 4 5 6 7; do
  t=$(ruby -e "puts ($dur * $i / 8.0).round(3)")
  ${VORK:-$HOME/.local/bin/vork} render "$2.json" --out "$d/$i.png" --at "$t" --profile std/previs --set resolution=360x360 >/dev/null 2>&1
done
ffmpeg -v error -y -i "$d/%d.png" -vf tile=4x2 -frames:v 1 "$out"; rm -rf "$d"; echo "$out"
