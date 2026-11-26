#!/bin/sh
# Contact sheet of baked clips on a game character (software Vulkan). Usage: tools/dev/clip_sheet.sh --clips=a,b --out=<png> [...]
cd "$(dirname "$0")/../.." || exit 1
GODOT="${GODOT:-.tools/Godot_v4.6-stable_linux.x86_64}"
export VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/opt/lavapipe/lvp_icd.json}"
xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-method mobile --resolution 1280x720 --fixed-fps 30 res://tools/dev/clip_sheet.tscn -- "$@" 2>&1 | grep -v -E "ALSA|audio|^$|Godot Engine|Vulkan|lavapipe" | head -30
