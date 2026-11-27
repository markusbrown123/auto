#!/bin/sh
# rec.sh <name> <seconds> [game args]  -> marketing/build_check/<name>.mp4 + logs in scratchpad
S=/tmp/claude-0/-home-user/5115f220-93df-583d-ba87-f4512b27fb27/scratchpad
cd /home/user/auto/hollow-reign || exit 1
NAME="$1"; SECS="$2"; shift 2
export VK_ICD_FILENAMES=/opt/lavapipe/lvp_icd.json
TMP="$S/rec_$NAME.avi"
xvfb-run -a -s "-screen 0 960x540x24" .tools/Godot_v4.6-stable_linux.x86_64 --path . -s "$S/bc_wrap.gd" --rendering-method mobile --resolution 960x540 --fixed-fps 30 \
	--write-movie "$TMP" --quit-after $((SECS * 30)) -- --bclog="$S/$NAME.bclog" "$@" > "$S/$NAME.stdout" 2>&1
ffmpeg -y -loglevel error -i "$TMP" -c:v libx264 -crf 27 -preset slow -pix_fmt yuv420p -c:a aac -b:a 96k "marketing/build_check/$NAME.mp4" && echo "recorded $NAME" && rm -f "$TMP"
