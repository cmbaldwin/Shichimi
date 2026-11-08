#!/bin/sh
# Render on the Escalante Mac (nice'd) instead of this laptop. Usage: script/vork/remote.sh squat push_up ...
# Env: SAMPLES/CRF/PROFILE pass through; DEST=dir puts the results there instead of public/videos.
# Remote log: escalante:~/Dev/shichimi/log/render.log. Vork is GPU-bound (no thread flag), so only nice limits load.
set -eu
cd "$(dirname "$0")/../.."
HOST=${HOST:-escalante}; R=Dev/shichimi; DEST=${DEST:-public/videos}
rsync -a --delete --exclude .git --exclude tmp/ --exclude log/ --exclude storage/ --exclude 'db/*.sqlite3*' \
  --exclude public/videos/ --exclude .env --exclude node_modules ./ "$HOST:$R/"
ssh "$HOST" "SAMPLES=${SAMPLES:-64} CRF=${CRF:-23} PROFILE=${PROFILE:-std/final} sh -s -- $*" <<'REMOTE'
set -eu
export PATH=/opt/homebrew/bin:$HOME/.local/bin:$PATH; eval "$(rbenv init - sh)"
cd ~/Dev/shichimi; mkdir -p log tmp/pids public/videos; exec >>log/render.log 2>&1
echo "== $(date) render $*"
if ! curl -fs -o /dev/null http://localhost:3117/up; then
  nice -n 19 taskpolicy -b bin/rails s -p 3117 -P tmp/pids/render.pid -d >/dev/null
  until curl -fs -o /dev/null http://localhost:3117/up; do sleep 2; done
fi
trap 'kill "$(cat tmp/pids/render.pid)" 2>/dev/null || true' EXIT
nice -n 19 taskpolicy -b sh script/vork/render.sh "$@"
REMOTE
mkdir -p "$DEST"
for s in "$@"; do rsync -a "$HOST:$R/public/videos/$s.mp4" "$HOST:$R/public/videos/$s.webp" "$DEST/"; done
