#!/bin/sh
# Runs the headless test suites. Usage: tools/test.sh [path-to-godot]
cd "$(dirname "$0")/.." || exit 1
GODOT="${1:-${GODOT:-.tools/Godot_v4.6-stable_linux.x86_64}}"
"$GODOT" --headless --path . --import >/dev/null 2>&1
rc=0
for suite in tests integration; do
	echo "== $suite"
	"$GODOT" --headless --path . "res://tests/$suite.tscn" > "/tmp/hr_$suite.log" 2>&1 || rc=1
	grep -v -E "^(Godot Engine|$)|ObjectDB|object.cpp|resources still in use|resource.cpp" "/tmp/hr_$suite.log"
	if grep -q "SCRIPT ERROR" "/tmp/hr_$suite.log"; then rc=1; fi
done
exit $rc
