#!/bin/sh
# Records gameplay to marketing/demos/<name>.mp4 (software Vulkan, offline at a fixed 30 fps, so timing is exact).
# Usage: tools/record.sh <name> <seconds> [game args...]
cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-.tools/Godot_v4.6-stable_linux.x86_64}"
NAME="$1"; SECS="$2"; shift 2
export VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/opt/lavapipe/lvp_icd.json}"
TMP="${TMPDIR:-/tmp}/hr_rec_$NAME.avi"
mkdir -p marketing/demos
xvfb-run -a -s "-screen 0 960x540x24" "$GODOT" --path . --rendering-method mobile --resolution 960x540 --fixed-fps 30 \
	--write-movie "$TMP" --quit-after $((SECS * 30)) -- "$@" >/dev/null 2>&1
ffmpeg -y -loglevel error -i "$TMP" -c:v libx264 -crf 27 -preset slow -pix_fmt yuv420p -c:a aac -b:a 96k "marketing/demos/$NAME.mp4" && echo "recorded $NAME"
