#!/bin/bash
set -euo pipefail
if [[ "${GITHUB_ACTIONS:-}" != true ]]; then
  echo "This smoke test changes the disposable CI account's appearance. Run it only in GitHub Actions." >&2
  exit 1
fi
source_app="$(cd "$1" && pwd)"
output="${2:-artifacts/macos-launch-check}"
mkdir -p "$output"
mkdir -p "$HOME/Applications"
install_root="$(mktemp -d "$HOME/Applications/CommonCopy-CI.XXXXXX")"
app_pid=""
cleanup() {
  if [[ -n "$app_pid" ]]; then kill "$app_pid" 2>/dev/null || true; fi
  rm -rf "$install_root"
}
trap cleanup EXIT
# Outside Applications the packaged app must explain installation first.
"$source_app/Contents/MacOS/CommonCopyMac" > "$output/install-required.log" 2>&1 &
app_pid=$!
sleep 3
kill -0 "$app_pid"
screencapture -x "$output/install-required.png" || true
kill "$app_pid"
wait "$app_pid" 2>/dev/null || true
app_pid=""
# A unique disposable location exercises the same installed-path gate as users.
ditto "$source_app" "$install_root/CommonCopy.app"
app="$install_root/CommonCopy.app"
# Use only the runner's disposable user account, never a tester's library.
"$app/Contents/MacOS/CommonCopyMac" > "$output/launch.log" 2>&1 &
app_pid=$!
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
kill "$app_pid"
wait "$app_pid" 2>/dev/null || true
printf '%s' '{"operation":"appearance","appearance":"Dark"}' | \
  "$app/Contents/Helpers/Core/CommonCopy.DesktopBridge" \
  "$HOME/Library/Application Support/CommonCopy" > /dev/null
"$app/Contents/MacOS/CommonCopyMac" > "$output/dark-launch.log" 2>&1 &
app_pid=$!
sleep 5
kill -0 "$app_pid"
if screencapture -x "$output/dark-appearance.png"; then
  echo "Captured monochrome Dark for visual inspection."
else
  echo "Dark screen capture unavailable; device testing remains required."
fi
