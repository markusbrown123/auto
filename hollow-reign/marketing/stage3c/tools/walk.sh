#!/bin/sh
# Stage 3C cost: the whole continuous Courtyard walked (--screen=routewalk --routecost) at 1280x720, render cost every
# 2 s of game time and at each stop. Usage: walk.sh <name> [game args, e.g. --nodress]. Only cost lines are kept.
cd "$(dirname "$0")/../../.." || exit 1
NAME="$1"; shift
export VK_ICD_FILENAMES=/opt/lavapipe/lvp_icd.json XDG_DATA_HOME=/tmp/hr_stage3c_walk_$NAME
mkdir -p $XDG_DATA_HOME
timeout ${LIMIT:-5400} xvfb-run -a -s "-screen 0 1280x720x24" .tools/Godot_v4.6-stable_linux.x86_64 --path . --rendering-method mobile \
  --resolution 1280x720 --fixed-fps ${FPS:-10} -- --screen=routewalk --routecost "$@" 2>&1 \
  | grep --line-buffered -a -E "ROUTECOST|ROUTEWALK|DRESS|SCRIPT ERROR" >> marketing/stage3c/walk_$NAME.log
echo "walk $NAME exit $? $(date)" >> marketing/stage3c/walk_done.txt
