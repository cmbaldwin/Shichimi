#!/bin/sh
# Realistic exercise videos on Mixamo characters (male = Adam, female = Jody). Raw FBX: ~/Dev/shichimi-assets/mixamo/<who>/.
# Mixamo terms forbid redistributing raw files: only the rendered videos go in the repo.
#   script/vork/mixamo.sh build adam squat push_up   # laptop: Blender FBX/retarget -> GLB, scene.rb -> tmp/vorkm/<who>/
#   script/vork/mixamo.sh render [adam/squat ...]    # push tmp/vorkm to Escalante, render everything there (nohup, nice)
#   script/vork/mixamo.sh pull                       # fetch finished public/videos/<who>/*.mp4|webp
# Clip choice per slug lives in script/vork/mixamo.txt: "slug clip.fbx [start end]" or "slug retarget" (our keyframes).
set -eu
cd "$(dirname "$0")/../.."
B=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
A=$HOME/Dev/shichimi-assets/mixamo
HOST=${HOST:-escalante}
SSH="ssh -o ControlMaster=auto -o ControlPath=$HOME/.ssh/cm-%r@%h:%p -o ControlPersist=10m"
cmd=$1; shift
case $cmd in
build)
  who=$1; shift
  mkdir -p "tmp/mixamo/$who" "tmp/vorkm/$who"
  for slug in "$@"; do
    yaw=$(ruby -ryaml -e "puts YAML.load_file('config/catalog/motions/$slug.yml')['yaw']")
    set -- $(grep "^$slug " script/vork/mixamo.txt | cut -d' ' -f2-)
    if [ "$1" = retarget ]; then
      n=$(ruby -rjson -e "puts JSON.parse(File.read('tmp/exports/$slug.json'))['frames']")
      $B -b -P script/mocap/retarget.py -- "$A/$who/squat.fbx" "tmp/exports/$slug.glb" "tmp/mixamo/$who/$slug.blend" | grep RETARGET
      $B -b -P script/mocap/mixamo_glb.py -- "tmp/mixamo/$who/$slug.blend" "tmp/mixamo/$who" "$slug" "$yaw" 0 "$n" | grep -E "WROTE|Error"
    else
      $B -b -P script/mocap/mixamo_glb.py -- "$A/$who/$1" "tmp/mixamo/$who" "$slug" "$yaw" ${2:-} ${3:-} | grep -E "LOOP|WROTE|Error"
    fi
    SRC="tmp/mixamo/$who" ruby script/vork/scene.rb "$slug" "tmp/vorkm/$who"
  done ;;
render)
  rsync -a -e "$SSH" script/vork/ "$HOST:Dev/shichimi/script/vork/"
  rsync -a -e "$SSH" tmp/vorkm/ "$HOST:Dev/shichimi/tmp/vorkm/"
  rsync -a -e "$SSH" "$A/" "$HOST:Dev/shichimi-assets/mixamo/"
  $SSH "$HOST" "cd ~/Dev/shichimi && mkdir -p log && SAMPLES=${SAMPLES:-32} nohup sh script/vork/mixamo_remote.sh $* >>log/mixamo.log 2>&1 &"
  echo "rendering; tail: $SSH $HOST tail ~/Dev/shichimi/log/mixamo.log" ;;
pull)
  rsync -a -e "$SSH" --include='*/' --include='*.mp4' --include='*.webp' --exclude='*' \
    "$HOST:Dev/shichimi/public/videos/male" "$HOST:Dev/shichimi/public/videos/female" public/videos/ || true ;;
esac
