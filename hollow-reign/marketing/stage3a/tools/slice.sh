#!/bin/sh
# Stage 3A: the first-boss slice played by touch (src/dev/slice_bot.gd), both bodies, logs and frames in marketing/stage3a/.
cd "$(dirname "$0")/../../.." || exit 1
export VK_ICD_FILENAMES=/opt/lavapipe/lvp_icd.json
export XDG_DATA_HOME="${XDG_DATA_HOME:-/tmp/hr_stage3a_slice}"
mkdir -p "$XDG_DATA_HOME"
for body in m f; do
  xvfb-run -a -s "-screen 0 960x540x24" .tools/Godot_v4.6-stable_linux.x86_64 --path . --rendering-method mobile --resolution 960x540 --fixed-fps 30 \
    -- --screen=slice --body=$body --fast --die=1 --log=$PWD/marketing/stage3a/slice_$body.log --snaps=$PWD/marketing/stage3a/slice_$body --snap_every=6 \
    > marketing/stage3a/slice_$body.out 2>&1
  echo "slice $body exit $?" >> marketing/stage3a/slice_done.txt
done
