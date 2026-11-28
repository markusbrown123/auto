#!/bin/sh
# Stage 3B: the first-boss slice played by touch (src/dev/slice_bot.gd), 640x360, fixed 30 fps, no movie.
# Usage: slice.sh <body> [extra bot args]. Logs in marketing/stage3b/slice_<body>*.
cd "$(dirname "$0")/../../.." || exit 1
body="$1"; shift
export VK_ICD_FILENAMES=/opt/lavapipe/lvp_icd.json
export XDG_DATA_HOME="/tmp/hr_stage3b_slice_$body"
rm -rf "$XDG_DATA_HOME"; mkdir -p "$XDG_DATA_HOME" marketing/stage3b/slice_$body
xvfb-run -a -s "-screen 0 640x360x24" .tools/Godot_v4.6-stable_linux.x86_64 --path . --rendering-method mobile --resolution 640x360 --fixed-fps 30 \
  -- --screen=slice --body=$body --log=$PWD/marketing/stage3b/slice_$body.log --snaps=$PWD/marketing/stage3b/slice_$body --snap_every=10 "$@" \
  > marketing/stage3b/slice_$body.out 2>&1
echo "slice $body exit $? $(date)" >> marketing/stage3b/slice_done.txt
