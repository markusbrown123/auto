#!/bin/sh
# Stage 3A: the whole continuous Courtyard walked at normal speed (--screen=routewalk: fights passed over), recorded like
# tools/record.sh (software Vulkan, fixed 30 fps, crf 27), split into clips of at most 3 MB, with a contact sheet each.
# Usage: record_walk.sh <name> <max seconds> [game args]
cd "$(dirname "$0")/../../.." || exit 1
NAME="$1"; SECS="$2"; shift 2
OUT=marketing/stage3a/clips
mkdir -p $OUT
export VK_ICD_FILENAMES=/opt/lavapipe/lvp_icd.json XDG_DATA_HOME=/tmp/hr_stage3a_rec_$NAME
mkdir -p $XDG_DATA_HOME
TMP=/tmp/hr_stage3a_$NAME.avi
xvfb-run -a -s "-screen 0 960x540x24" .tools/Godot_v4.6-stable_linux.x86_64 --path . --rendering-method mobile --resolution 960x540 --fixed-fps 30 \
  --write-movie "$TMP" --quit-after $((SECS * 30)) -- --screen=routewalk --routecost "$@" > marketing/stage3a/rec_$NAME.log 2>&1
ffmpeg -y -loglevel error -i "$TMP" -c:v libx264 -crf 27 -preset slow -pix_fmt yuv420p -c:a aac -b:a 96k "$OUT/${NAME}_full.mp4"
DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT/${NAME}_full.mp4")
SIZE=$(stat -c %s "$OUT/${NAME}_full.mp4")
SEG=$(python3 -c "print(max(8, int(float('$DUR') * 2.4e6 / max($SIZE, 1))))")
ffmpeg -y -loglevel error -i "$OUT/${NAME}_full.mp4" -c copy -f segment -segment_time $SEG -reset_timestamps 1 "$OUT/${NAME}_%02d.mp4"
for c in $OUT/${NAME}_[0-9][0-9].mp4; do
  ffmpeg -y -loglevel error -i "$c" -vf "fps=1/3,scale=320:-1,tile=4x3" -frames:v 1 "${c%.mp4}_sheet.jpg"
done
rm -f "$OUT/${NAME}_full.mp4" "$TMP"
echo "recorded $NAME $(date)" >> marketing/stage3a/rec_done.txt
