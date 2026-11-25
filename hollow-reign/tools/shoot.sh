#!/bin/sh
# Renders screenshots with software Vulkan (no GPU needed).
# Usage: tools/shoot.sh <outdir> <times,comma,separated> [extra game args...]
cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-.tools/Godot_v4.6-stable_linux.x86_64}"
OUT="$1"; AT="$2"; shift 2
export VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/opt/lavapipe/lvp_icd.json}"
xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-method mobile --resolution 1280x720 --fixed-fps 30 -- --shots="$OUT" --at="$AT" "$@" 2>&1 | grep -v -E "ALSA|audio|^$|Godot Engine|Vulkan|lavapipe" | head -30
