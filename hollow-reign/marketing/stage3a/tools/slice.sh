#!/bin/sh
# Stage 3A: the first-boss slice played by touch (src/dev/slice_bot.gd). Usage: slice.sh <body> [extra bot args]
# Logs and frames in marketing/stage3a/slice_<body>*.
cd "$(dirname "$0")/../../.." || exit 1
body="$1"; shift
export VK_ICD_FILENAMES=/opt/lavapipe/lvp_icd.json
export XDG_DATA_HOME="/tmp/hr_stage3a_slice_$body"
mkdir -p "$XDG_DATA_HOME" marketing/stage3a/slice_$body
xvfb-run -a -s "-screen 0 ${RES:-960x540}x24" .tools/Godot_v4.6-stable_linux.x86_64 --path . --rendering-method mobile --resolution ${RES:-960x540} --fixed-fps 30 \
  -- --screen=slice --body=$body --log=$PWD/marketing/stage3a/slice_$body.log --snaps=$PWD/marketing/stage3a/slice_$body --snap_every=6 "$@" \
  > marketing/stage3a/slice_$body.out 2>&1
echo "slice $body exit $? $(date)" >> marketing/stage3a/slice_done.txt
