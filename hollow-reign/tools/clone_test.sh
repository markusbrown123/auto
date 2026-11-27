#!/bin/sh
# Proves that what is pushed to GitHub is enough to run the game: clones the branch fresh into a scratch folder,
# imports it and captures one duel frame. Look at the frame: a white knight means textures are missing from the repository.
# Usage: tools/clone_test.sh [scratch_dir]     (takes about 20 minutes on the software renderer)
HERE="$(cd "$(dirname "$0")/.." && pwd)"; G="$HERE/.tools/Godot_v4.6-stable_linux.x86_64"
S="${1:-${TMPDIR:-/tmp}/hr_clone_test}"; rm -rf "$S"; mkdir -p "$S" && cd "$S" || exit 1
git clone -q --depth 1 -b "$(git -C "$HERE" rev-parse --abbrev-ref HEAD)" "$(git -C "$HERE" remote get-url origin)" fresh || exit 1
cd fresh/hollow-reign && mkdir -p .tools && ln -sf "$G" .tools/
"$G" --headless --import > "$S/import.log" 2>&1; echo "import errors: $(grep -ci error "$S/import.log")"
tools/shoot.sh "$S/shot" 2 --demo=ashen_sentinel --bot=3 --skip_intro > "$S/run.log" 2>&1
echo "run errors: $(grep -ci 'failed loading\|unable to open' "$S/run.log")"; ls "$S/shot"
