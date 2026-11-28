#!/bin/sh
cd "$(dirname "$0")/../../.." || exit 1
export RES=960x540 XDG_DATA_HOME=/tmp/hr_stage3a_guard
mkdir -p $XDG_DATA_HOME
timeout 5000 tools/shoot.sh marketing/stage3a/shots 6,18,21,40 --screen=routewalk --from=1 --name=guardhouse --routecost > marketing/stage3a/guard.log 2>&1
timeout 5000 tools/shoot.sh marketing/stage3a/shots 5,16,19 --screen=routewalk --from=4 --name=murderhole --routecost > marketing/stage3a/murder.log 2>&1
echo done >> marketing/stage3a/guard_done.txt
