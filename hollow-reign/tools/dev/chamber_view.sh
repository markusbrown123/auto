#!/bin/sh
# Stage 1: the awakening chamber from fixed cameras (src/dev/chamber_view.gd). Usage: tools/dev/chamber_view.sh --out=<dir> [--views=a,b] [...]
cd "$(dirname "$0")/../.." || exit 1
GODOT="${GODOT:-.tools/Godot_v4.6-stable_linux.x86_64}"
export VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/opt/lavapipe/lvp_icd.json}"
RES="${RES:-1280x720}"
xvfb-run -a -s "-screen 0 ${RES}x24" "$GODOT" --path . --rendering-method mobile --resolution "$RES" res://src/dev/chamber_view.tscn -- "$@" 2>&1 | grep -v -E "ALSA|audio|^$|Godot Engine|Vulkan|lavapipe" | head -60
