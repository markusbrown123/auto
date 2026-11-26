#!/bin/sh
# Runs the headless test suites. Usage: tools/test.sh [path-to-godot]
cd "$(dirname "$0")/.." || exit 1
GODOT="${1:-${GODOT:-.tools/Godot_v4.6-stable_linux.x86_64}}"
"$GODOT" --headless --path . --import >/dev/null 2>&1
rc=0
for suite in tests cine integration; do
	echo "== $suite"
	"$GODOT" --headless --path . "res://tests/$suite.tscn" > "/tmp/hr_$suite.log" 2>&1 || rc=1
	grep -v -E "^(Godot Engine|$)|ObjectDB|object.cpp|resources still in use|resource.cpp" "/tmp/hr_$suite.log"
	if grep -q "SCRIPT ERROR" "/tmp/hr_$suite.log"; then rc=1; fi
done
echo "== touch"
if command -v xvfb-run >/dev/null 2>&1; then
	VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/opt/lavapipe/lvp_icd.json}" xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-method mobile --resolution 1280x720 res://tests/touch.tscn > /tmp/hr_touch.log 2>&1 || rc=1
else
	"$GODOT" --path . --resolution 1280x720 res://tests/touch.tscn > /tmp/hr_touch.log 2>&1 || rc=1
fi
grep -E "^  (ok|FAIL)|^touch:|SCRIPT ERROR" /tmp/hr_touch.log
# the cinematic duel's footage only decodes with a real window
if [ -f assets/video/sentinel_idle.ogv ]; then
	echo "== cine playback"
	if command -v xvfb-run >/dev/null 2>&1; then
		VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/opt/lavapipe/lvp_icd.json}" xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-method mobile --resolution 1280x720 --max-fps 60 res://tests/cine_playback.tscn > /tmp/hr_cinepb.log 2>&1 || rc=1
	else
		"$GODOT" --path . --resolution 1280x720 --max-fps 60 res://tests/cine_playback.tscn > /tmp/hr_cinepb.log 2>&1 || rc=1
	fi
	grep -E "^  |^cine playback|SCRIPT ERROR" /tmp/hr_cinepb.log
fi
exit $rc
