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
swift scripts/render-dmg-background.swift src/CommonCopy.Mac/Assets/CommonCopyLogo.svg "$work/staging/.background/installer.tiff"
hdiutil create -quiet -volname "CommonCopy Installer" -srcfolder "$work/staging" -fs HFS+ -format UDRW "$work/writable.dmg"
hdiutil attach -readwrite -noverify -noautoopen -plist "$work/writable.dmg" > "$work/attach.plist"
mount="$(python3 - "$work/attach.plist" <<'PY'
import plistlib,sys
with open(sys.argv[1],'rb') as f: p=plistlib.load(f)
print(next(e['mount-point'] for e in p['system-entities'] if 'mount-point' in e))
PY
)"
# Finder owns the real icon positions and .DS_Store; no simulated installer UI.
osascript - "$mount" <<'APPLESCRIPT'
on run argv
  tell application "Finder"
    tell disk "CommonCopy Installer"
      open
      delay 1
      set current view of container window to icon view
      set toolbar visible of container window to false
      set statusbar visible of container window to false
      set bounds of container window to {100, 100, 820, 640}
      set theViewOptions to the icon view options of the container window
      set arrangement of theViewOptions to not arranged
      set icon size of theViewOptions to 110
      set text size of theViewOptions to 12
      set background picture of theViewOptions to file ".background:installer.tiff"
      set position of item "CommonCopy.app" to {210, 330}
      set position of item "Applications" to {510, 330}
      close container window
      open
      update without registering applications
      delay 3
    end tell
  end tell
end run
APPLESCRIPT
sync
hdiutil detach "$mount" -quiet
mount=""
hdiutil convert -quiet "$work/writable.dmg" -format UDZO -imagekey zlib-level=9 -o "$output"
hdiutil verify "$output"
echo "Built $output"

