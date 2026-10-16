#!/bin/bash
set -euo pipefail
app="$(cd "$1" && pwd)"
output="${2:-artifacts/macos-launch-check}"
mkdir -p "$output"
# Use only the runner's disposable user account, never a tester's library.
"$app/Contents/MacOS/CommonCopyMac" > "$output/launch.log" 2>&1 &
app_pid=$!
trap 'kill "$app_pid" 2>/dev/null || true' EXIT
sleep 5
if ! kill -0 "$app_pid" 2>/dev/null; then
  echo "The packaged Mac application exited during startup." >&2
  exit 1
fi
echo "Packaged AppKit application stayed running through startup."
if screencapture -x "$output/first-launch.png"; then
  echo "Captured the runner's first-launch screen for visual inspection."
else
  echo "Screen capture unavailable in this runner session; device visual testing remains required."
fi
