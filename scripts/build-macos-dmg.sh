#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
[[ "$(uname -s)" == Darwin ]] || { echo "DMG packaging requires macOS." >&2; exit 1; }
app="${1:-$root/artifacts/macos-arm64/CommonCopy.app}"
[[ -d "$app" ]] || { echo "Build CommonCopy.app first." >&2; exit 1; }
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
output="$root/artifacts/CommonCopy-$version-macos-arm64.dmg"
work="$(mktemp -d "$root/artifacts/dmg-build.XXXXXX")"
mount=""
cleanup() {
  if [[ -n "$mount" ]]; then hdiutil detach "$mount" -quiet || true; fi
  rm -rf "$work"
}
trap cleanup EXIT
mkdir -p "$work/staging/.background"
ditto "$app" "$work/staging/CommonCopy.app"
ln -s /Applications "$work/staging/Applications"
swift scripts/render-dmg-background.swift src/CommonCopy.Mac/Assets/CommonCopyLogo.png "$work/staging/.background/installer.png"
hdiutil create -quiet -volname "CommonCopy Installer" -srcfolder "$work/staging" -fs HFS+ -format UDRW "$work/writable.dmg"
hdiutil attach -quiet -readwrite -noverify -noautoopen -plist "$work/writable.dmg" > "$work/attach.plist"
mount="$(python3 - "$work/attach.plist" <<'PY'
import plistlib,sys
with open(sys.argv[1],'rb') as f: p=plistlib.load(f)
print(next(e['mount-point'] for e in p['system-entities'] if 'mount-point' in e))
PY
)"
# Finder owns the real icon positions and .DS_Store; no simulated installer UI.
osascript - "$mount" <<'APPLESCRIPT'
on run argv
  set diskFolder to POSIX file (item 1 of argv) as alias
  tell application "Finder"
    open diskFolder
    tell container window of diskFolder
      set current view to icon view
      set toolbar visible to false
      set statusbar visible to false
      set bounds to {100, 100, 820, 580}
      set viewOptions to icon view options
      set arrangement of viewOptions to not arranged
      set icon size of viewOptions to 110
      set text size of viewOptions to 12
      set background picture of viewOptions to file ".background:installer.png" of diskFolder
    end tell
    set position of item "CommonCopy.app" of diskFolder to {210, 220}
    set position of item "Applications" of diskFolder to {510, 220}
    close container window of diskFolder
    open diskFolder
    update diskFolder without registering applications
    delay 3
  end tell
end run
APPLESCRIPT
sync
hdiutil detach "$mount" -quiet
mount=""
hdiutil convert -quiet "$work/writable.dmg" -format UDZO -imagekey zlib-level=9 -o "$output"
hdiutil verify "$output"
echo "Built $output"
