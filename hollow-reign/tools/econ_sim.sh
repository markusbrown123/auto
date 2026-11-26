#!/bin/sh
# Plays the campaign's reward stream headlessly and prints the economy report.
# Usage: tools/econ_sim.sh [--style=sloppy|skilled] [--seed=N]
cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-.tools/Godot_v4.6-stable_linux.x86_64}"
"$GODOT" --headless --path . res://tools/econ_sim.tscn -- "$@" 2>&1 | grep -v -E "^(Godot Engine|$)|ObjectDB|object.cpp|resources still in use|resource.cpp"
