#!/bin/sh
# Stage 3C: a stretch of the continuous Courtyard walked at the road's pace (--screen=routewalk, fights passed over),
# software Vulkan at a fixed 30 fps, 960x540, crf 28, one clip of at most 3 MB with a contact sheet.
# Usage: record_walk.sh <name> <seconds> [game args]
cd "$(dirname "$0")/../../.." || exit 1
NAME="$1"; SECS="$2"; shift 2
OUT=marketing/stage3c/clips
mkdir -p $OUT
export VK_ICD_FILENAMES=/opt/lavapipe/lvp_icd.json XDG_DATA_HOME=/tmp/hr_stage3c_rec_$NAME
mkdir -p $XDG_DATA_HOME
TMP=/tmp/hr_stage3c_$NAME.avi
xvfb-run -a -s "-screen 0 960x540x24" .tools/Godot_v4.6-stable_linux.x86_64 --path . --rendering-method mobile --resolution 960x540 --fixed-fps 30 \
  --write-movie "$TMP" --quit-after $((SECS * 30)) -- --screen=routewalk "$@" 2>&1 | grep -a -E "ROUTEWALK|SCRIPT ERROR" > marketing/stage3c/rec_$NAME.log
ffmpeg -y -loglevel error -i "$TMP" -c:v libx264 -crf ${CRF:-28} -preset slow -pix_fmt yuv420p -an -fs 3000000 "$OUT/$NAME.mp4"
ffmpeg -y -loglevel error -i "$OUT/$NAME.mp4" -vf "fps=1/4,scale=320:-1,tile=4x4" -frames:v 1 "$OUT/${NAME}_sheet.jpg"
rm -f "$TMP"
echo "recorded $NAME $(date) $(stat -c %s $OUT/$NAME.mp4)" >> marketing/stage3c/rec_done.txt
