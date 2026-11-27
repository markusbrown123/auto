#!/bin/sh
# First import on a Mac, without opening the editor window. Run this once after cloning or pulling, then open the
# project in Godot as usual. It is the same headless import that tools/clone_test.sh proves on every build commit.
# Usage: tools/mac_import.sh [path to Godot.app]      (default /Applications/Godot.app)
HERE="$(cd "$(dirname "$0")/.." && pwd)"; APP="${1:-/Applications/Godot.app}"; G="$APP/Contents/MacOS/Godot"
[ -x "$G" ] || { echo "Godot not found at $APP. Pass its path: tools/mac_import.sh /path/to/Godot.app"; exit 1; }
cd "$HERE" || exit 1
for pass in 1 2; do
  echo "Import pass $pass of 2 (several minutes, no window appears)..."
  "$G" --headless --path "$HERE" --import > "$HERE/import_pass_$pass.log" 2>&1 || echo "pass $pass ended with an error code; see import_pass_$pass.log"
done
CHANGED="$(git status --short | grep -c '\.import$')"
echo "Done. Import files changed by this Mac: $CHANGED (should be 0). Logs: import_pass_1.log, import_pass_2.log"
