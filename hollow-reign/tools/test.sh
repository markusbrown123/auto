#!/bin/sh
# Runs the headless test suite. Usage: tools/test.sh [path-to-godot]
cd "$(dirname "$0")/.." || exit 1
GODOT="${1:-${GODOT:-.tools/Godot_v4.6-stable_linux.x86_64}}"
"$GODOT" --headless --path . --import >/dev/null 2>&1
"$GODOT" --headless --path . res://tests/tests.tscn 2>&1 | grep -v -E "^(Godot Engine|$)"
exit "${PIPESTATUS:-0}"
