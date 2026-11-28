#!/bin/sh
cd "$(dirname "$0")/../../.." || exit 1
export RES=960x540 XDG_DATA_HOME=/tmp/hr_stage3a_fix
mkdir -p $XDG_DATA_HOME
timeout 6000 tools/shoot.sh marketing/stage3a/shots 14,18,22,25,28 --screen=routewalk --from=4 --name=murder_after > marketing/stage3a/fix1.log 2>&1
timeout 6000 tools/shoot.sh marketing/stage3a/shots 6,10,14 --screen=routewalk --from=5 --name=shrine_after > marketing/stage3a/fix2.log 2>&1
timeout 6000 tools/shoot.sh marketing/stage3a/shots 8,13 --screen=routewalk --from=3 --name=winch_after > marketing/stage3a/fix3.log 2>&1
echo done > marketing/stage3a/fix_done.txt
