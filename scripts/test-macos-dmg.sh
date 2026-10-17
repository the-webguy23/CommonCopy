#!/bin/bash
set -euo pipefail
[[ "${GITHUB_ACTIONS:-}" == true ]] || { echo "Use only the disposable CI desktop." >&2; exit 1; }
image="$1"
source_app="$2"
output="artifacts/macos-installer-check"
mkdir -p "$output"
work="$(mktemp -d)"
mount=""
cleanup() {
  if [[ -n "$mount" ]]; then hdiutil detach "$mount" -quiet || true; fi
  rm -rf "$work"
}
trap cleanup EXIT
hdiutil verify "$image"
hdiutil attach -readonly -noverify -autoopen -plist "$image" > "$work/attach.plist"
mount="$(python3 - "$work/attach.plist" <<'PY'
import plistlib,sys
with open(sys.argv[1],'rb') as f: p=plistlib.load(f)
print(next(e['mount-point'] for e in p['system-entities'] if 'mount-point' in e))
PY
)"
[[ "$(readlink "$mount/Applications")" == /Applications ]]
[[ -s "$mount/CommonCopy.app/Contents/Resources/CommonCopyLogo.svg" ]]
[[ -s "$mount/.DS_Store" && -s "$mount/.background/installer.png" ]]
codesign --verify --deep --strict "$mount/CommonCopy.app"
# The drag operation copies a bundle. Test that same copy without touching /Applications.
ditto "$mount/CommonCopy.app" "$work/CommonCopy.app"
python3 - "$source_app" "$work/CommonCopy.app" <<'PY'
import pathlib,hashlib,sys
def manifest(root):
 root=pathlib.Path(root)
 return {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*') if p.is_file()}
assert manifest(sys.argv[1])==manifest(sys.argv[2]), 'DMG changed the tested application'
print('DMG application is byte-identical to the tested source bundle.')
PY
codesign --verify --deep --strict "$work/CommonCopy.app"
osascript - "$mount" <<'APPLESCRIPT'
on run argv
  tell application "Finder"
    activate
    open POSIX file (item 1 of argv)
    delay 2
  end tell
end run
APPLESCRIPT
screencapture -x "$output/installer.png"
hdiutil detach "$mount" -quiet
mount=""
bash scripts/smoke-test-macos.sh "$work/CommonCopy.app" "$output/installed-app"
echo "DMG integrity, layout metadata, Applications link, exact bundle copy, signature and copied-app launch passed."
