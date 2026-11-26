#!/bin/sh
# Imports the project and prints any script errors.
cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-.tools/Godot_v4.6-stable_linux.x86_64}"
"$GODOT" --headless --path . --import 2>&1 | grep -E "SCRIPT ERROR|Parse Error|at: GDScript" | head -40
