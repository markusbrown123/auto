#!/bin/sh
# Stage 3C stills: each stop of the continuous Courtyard on arrival (2.5 s) and walking on (11 s), with render cost,
# before (--nodress: the route as Stage 3A left it) and after. 1280x720. One Godot at a time.
# Usage: stops.sh before|after
cd "$(dirname "$0")/../../.." || exit 1
WHICH="$1"
ARG=""; [ "$WHICH" = before ] && ARG="--nodress"
export RES=1280x720 XDG_DATA_HOME=/tmp/hr_stage3c_stops
mkdir -p $XDG_DATA_HOME marketing/stage3c/$WHICH
for n in ${STOPS:-0 1 2 3 4 5 6}; do
  timeout 1500 tools/shoot.sh marketing/stage3c/$WHICH 2.5,11 --screen=routewalk --from=$n --name=stop$n --routecost $ARG \
    2>&1 | grep -a -E "ROUTECOST|render t=" > marketing/stage3c/$WHICH/stop$n.log
done
echo "stops $WHICH $(date)" >> marketing/stage3c/stops_done.txt
