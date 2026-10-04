#!/bin/sh
# Runs the headless test suite. Usage: ./run_tests.sh [filter]
# Fails on any failed test AND on any GDScript error printed during the run.
GODOT="${GODOT:-$(command -v godot || command -v godot4 || echo "$HOME/Applications/Godot.app/Contents/MacOS/Godot")}"
cd "$(dirname "$0")"
"$GODOT" --headless --path . --import >/dev/null 2>&1  # refresh class_name cache
OUT=$(mktemp)
"$GODOT" --headless --path . -s res://tests/run_tests.gd -- "$@" 2>&1 | tee "$OUT"
CODE=$(tail -1 "$OUT" | grep -q " 0 failed" && echo 0 || echo 1)
if grep -qE "SCRIPT ERROR|Parse Error|Compile Error" "$OUT"; then
  echo "!! GDScript errors during test run"
  CODE=1
fi
rm -f "$OUT"
exit $CODE
