#!/bin/bash
# Films every take of the cinematic Sentinel duel from the real scene, then
# cuts and encodes the clips Godot plays (Ogg Theora, 720p30, no audio).
# Usage: tools/render_clips.sh [take ...]      Needs ffmpeg; on Linux uses xvfb + software Vulkan.
cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-$PWD/.tools/Godot_v4.6-stable_linux.x86_64}"
export VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/opt/lavapipe/lvp_icd.json}"
TAKES="${*:-idle open counter recover victory defeat intro a_parry a_dodge a_block a_hit b_parry b_dodge b_block b_hit}"
mkdir -p art/takes assets/video
n=0
for t in $TAKES; do
	if [ ! -s "art/takes/$t.avi" ]; then
		( xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-method mobile --resolution 1280x720 \
			--write-movie "art/takes/$t.avi" --fixed-fps 30 res://src/cine/clip_stage.tscn -- --take="$t" > "/tmp/take_$t.log" 2>&1; echo "filmed $t" ) &
		n=$((n + 1))
		if [ $((n % 3)) = 0 ]; then wait; fi
	fi
done
wait
python3 tools/cut_clips.py
