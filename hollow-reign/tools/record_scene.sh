#!/bin/sh
# Records a scene at normal speed (offline at a fixed 30 fps, so the timing is exact) into <dir>/<name>_partN.mp4,
# parts of at most PART seconds so that each stays under ~3 MB, plus <name>_sheet.jpg: one frame every SHEET seconds.
# Usage: tools/record_scene.sh <dir> <name> <seconds> [game args...]     env: PART=40 SHEET=3 RES=960x540
cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-.tools/Godot_v4.6-stable_linux.x86_64}"
DIR="$1"; NAME="$2"; SECS="$3"; shift 3
PART="${PART:-40}"; SHEET="${SHEET:-3}"; RES="${RES:-960x540}"
export VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/opt/lavapipe/lvp_icd.json}"
TMP="${TMPDIR:-/tmp}/hr_scene_$NAME.avi"
mkdir -p "$DIR"
xvfb-run -a -s "-screen 0 ${RES}x24" "$GODOT" --path . --rendering-method mobile --resolution "$RES" --fixed-fps 30 \
	--write-movie "$TMP" --quit-after $((SECS * 30)) -- "$@" > "${TMPDIR:-/tmp}/hr_scene_$NAME.log" 2>&1
i=0; t=0
while [ "$t" -lt "$SECS" ]; do
	i=$((i + 1))
	ffmpeg -y -loglevel error -ss "$t" -t "$PART" -i "$TMP" -c:v libx264 -crf 28 -preset slow -pix_fmt yuv420p -c:a aac -b:a 80k "$DIR/${NAME}_part$i.mp4"
	t=$((t + PART))
done
N=$(( (SECS + SHEET - 1) / SHEET ))
COLS=6; ROWS=$(( (N + COLS - 1) / COLS ))
ffmpeg -y -loglevel error -i "$TMP" -vf "fps=1/$SHEET,scale=320:-1,tile=${COLS}x${ROWS}" -frames:v 1 -q:v 4 "$DIR/${NAME}_sheet.jpg"
rm -f "$TMP"
ls -la "$DIR" | grep "$NAME"
grep -E "SCRIPT ERROR|ERROR:" "${TMPDIR:-/tmp}/hr_scene_$NAME.log" | grep -v -E "ALSA|status < 0" | sort | uniq -c | head -10
