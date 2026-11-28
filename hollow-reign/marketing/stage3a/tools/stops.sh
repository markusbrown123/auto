#!/bin/sh
# Stage 3A stills: each stop of the continuous Courtyard on arrival (2.5 s) and walking on (11 s), with render cost.
cd "$(dirname "$0")/../../.." || exit 1
export RES=960x540 XDG_DATA_HOME=/tmp/hr_stage3a_stops
mkdir -p $XDG_DATA_HOME
for n in ${STOPS:-0 1 2 3 4 5 6}; do
  timeout 3000 tools/shoot.sh marketing/stage3a/shots 2.5,11 --screen=routewalk --from=$n --name=stop$n --routecost > marketing/stage3a/stop$n.log 2>&1
done
echo done > marketing/stage3a/stops_done.txt
