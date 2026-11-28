#!/bin/sh
# Stage 3B: records one capture at normal speed (software Vulkan, offline at a fixed 30 fps, like tools/record.sh),
# keeps it as one clip if it fits in 3 MB or splits it, and makes a contact sheet of each part.
# Usage: record_clip.sh <name> <seconds> [game args]   (RES=640x360 by default)
cd "$(dirname "$0")/../../.." || exit 1
NAME="$1"; SECS="$2"; shift 2
RES="${RES:-640x360}"
OUT=marketing/stage3b
export VK_ICD_FILENAMES=/opt/lavapipe/lvp_icd.json XDG_DATA_HOME=/tmp/hr_stage3b_rec_$NAME
mkdir -p $XDG_DATA_HOME
TMP=/tmp/hr_stage3b_$NAME.avi
xvfb-run -a -s "-screen 0 ${RES}x24" .tools/Godot_v4.6-stable_linux.x86_64 --path . --rendering-method mobile --resolution $RES --fixed-fps 30 \
  --write-movie "$TMP" --quit-after $((SECS * 30)) -- "$@" > $OUT/rec_$NAME.log 2>&1
ffmpeg -y -loglevel error -i "$TMP" -c:v libx264 -crf 27 -preset slow -pix_fmt yuv420p -c:a aac -b:a 96k "$OUT/${NAME}.mp4"
rm -f "$TMP"
SIZE=$(stat -c %s "$OUT/${NAME}.mp4")
if [ "$SIZE" -gt 3000000 ]; then
  DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT/${NAME}.mp4")
  SEG=$(python3 -c "print(max(8, int(float('$DUR') * 2.6e6 / max($SIZE, 1))))")
  ffmpeg -y -loglevel error -i "$OUT/${NAME}.mp4" -c copy -f segment -segment_time $SEG -reset_timestamps 1 "$OUT/${NAME}_%02d.mp4"
  rm -f "$OUT/${NAME}.mp4"
fi
for c in $OUT/${NAME}.mp4 $OUT/${NAME}_[0-9][0-9].mp4; do
  [ -f "$c" ] || continue
  D=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$c")
  R=$(python3 -c "print(max(0.2, 12.0 / max(float('$D'), 1.0)))")
  ffmpeg -y -loglevel error -i "$c" -vf "fps=$R,scale=320:-1,tile=4x3" -frames:v 1 "${c%.mp4}_sheet.jpg"
done
echo "recorded $NAME $(date)" >> $OUT/rec_done.txt
