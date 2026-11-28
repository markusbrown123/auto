#!/bin/sh
# Stage 3B: every capture of this stage, one after another (record_clip.sh each).
cd "$(dirname "$0")/../../.." || exit 1
R=marketing/stage3b/tools/record_clip.sh
$R enc0_patrol 80 --screen=routewalk --from=0 --fight --bot=1 --until=1
$R enc1_door 80 --screen=routewalk --from=1 --pick=1:1 --fight --bot=1 --until=2
$R enc2_banner 80 --screen=routewalk --from=2 --fight --bot=1 --until=3
$R int3_winch 55 --screen=routewalk --from=3 --until=4
$R enc4_barricade 85 --screen=routewalk --from=4 --want=4:rampart_brute --fight --bot=1 --until=5
$R enc4_colossus 85 --screen=routewalk --from=4 --fight --bot=1 --until=5
$R int1_guardhouse 60 --screen=routewalk --from=1 --pick=1:0 --until=2
$R int4_murderhole 75 --screen=routewalk --from=4 --pick=4:1
$R int5_shrine 45 --screen=routewalk --from=5 --until=6
$R enc6_sentinel 75 --screen=routewalk --from=6 --fight --bot=1
echo "all clips $(date)" >> marketing/stage3b/rec_done.txt
