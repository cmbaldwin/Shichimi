#!/usr/bin/env bash
# Process Kenney "Interface Sounds" (CC0) into public/audio/sfx/*.m4a.
# Usage: script/voices/sfx.sh <dir with the unzipped kenney_interfaceSounds .ogg files>
# Source zip: https://opengameart.org/sites/default/files/kenney_interfaceSounds.zip
set -euo pipefail
src=$1; out="$(dirname "$0")/../../public/audio/sfx"; mkdir -p "$out"
enc() { # name source extra-filter
  local f; f=$(find "$src" -name "$2" | head -1)
  local peak; peak=$(ffmpeg -i "$f" -af "${3:-anull}",volumedetect -f null - 2>&1 | sed -n 's/.*max_volume: \(.*\) dB/\1/p')
  ffmpeg -y -loglevel error -i "$f" -af "${3:-anull},volume=$(echo "-3 - $peak" | bc)dB,afade=t=out:st=0:d=0.01" \
    -ar 44100 -ac 1 -c:a aac -b:a 64k "$out/$1.m4a"
}
enc tick   glass_002.ogg
enc go     confirmation_001.ogg
enc rest   drop_004.ogg
enc switch switch_002.ogg
enc half   confirmation_002.ogg
enc done   glass_004.ogg "apad=pad_dur=1.6,aecho=0.8:0.7:120|260|420:0.45|0.3|0.2"
