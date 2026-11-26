#!/bin/sh
# Visual regression: renders fixed scenes and compares each with its golden image (structural similarity).
# Usage: tools/visual_test.sh           compare against tests/golden/
#        tools/visual_test.sh --update  write new golden images (look at them before committing)
# Scenes are ones that render the same every run: menus, the weapon line-up, single animation frames, both knights.
cd "$(dirname "$0")/.." || exit 1
OUT="${TMPDIR:-/tmp}/hr_visual"; GOLD=tests/golden; THRESH="${THRESH:-0.90}"
mkdir -p "$OUT" "$GOLD"
rc=0
shot() { # name time args...
	n="$1"; t="$2"; shift 2
	RES=640x360 tools/shoot.sh "$OUT/$n" "$t" "$@" >/dev/null 2>&1
	f=$(ls "$OUT/$n"/*.png 2>/dev/null | head -1)
	if [ -z "$f" ]; then echo "  FAIL  $n: nothing rendered"; rc=1; return; fi
	if [ "$MODE" = "--update" ]; then cp "$f" "$GOLD/$n.png"; echo "  gold  $n"; return; fi
	if [ ! -f "$GOLD/$n.png" ]; then echo "  FAIL  $n: no golden image"; rc=1; return; fi
	s=$(ffmpeg -loglevel info -i "$f" -i "$GOLD/$n.png" -lavfi ssim -f null - 2>&1 | sed -n 's/.*All:\([0-9.]*\).*/\1/p' | tail -1)
	if [ "$(python3 -c "print(1 if float('${s:-0}') >= $THRESH else 0)")" = "1" ]; then echo "  ok    $n ($s)"; else echo "  FAIL  $n: similarity $s below $THRESH"; rc=1; fi
}
MODE="$1"
shot title 3.0 --screen=title
shot journal 2.5 --screen=sanctuary --tab=Journal
shot armory 2.5 --screen=sanctuary --tab=Armory
shot weapons 2.0 --screen=weapons
shot knight_m_cut 1.0 --screen=animtest --clip=cut_c --body=m
shot knight_f_cut 1.0 --screen=animtest --clip=cut_c --body=f
shot knight_m_shield 1.0 --screen=animtest --clip=shield_idle --body=m
shot sentinel_cut 1.0 --screen=animtest --clip=cut_c --model=ashen_sentinel
shot training 2.5 --screen=training
[ "$MODE" = "--update" ] || echo "visual: $([ $rc = 0 ] && echo PASS || echo FAIL)"
exit $rc
