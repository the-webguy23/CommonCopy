#!/bin/bash
set -euo pipefail
# Repackage the reviewed DMG on the maintainer's Mac. No .NET SDK, certificate
# export, app installation, phrase data access, or public upload is involved.
# Only the two explicit notarytool submissions send software to Apple.
[[ "$(uname -s)" == Darwin ]] || { echo 'Notarization requires macOS.' >&2; exit 1; }
input="${1:?Usage: notarize-macos-dmg.sh reviewed.dmg [output-directory]}"
[[ -f "$input" ]] || { echo 'Input disk image not found.' >&2; exit 1; }
identity="${COMMONCOPY_SIGNING_IDENTITY:?Set COMMONCOPY_SIGNING_IDENTITY first.}"
profile="${COMMONCOPY_NOTARY_PROFILE:-CommonCopy-notary}"
root="$(cd "$(dirname "$0")/.." && pwd)"
output="${2:-$root/artifacts/notarized}"
mkdir -p "$output"
output="$(cd "$output" && pwd)"
[[ "$identity" == 'Developer ID Application: '* ]] || { echo 'Use Developer ID Application.' >&2; exit 1; }
xcrun --find notarytool >/dev/null
xcrun --find stapler >/dev/null
# Check access before modifying a copy or submitting anything.
xcrun notarytool history --keychain-profile "$profile" --output-format json >/dev/null
security find-identity -v -p codesigning | grep -F -- "\"$identity\"" >/dev/null || {
  echo 'The selected signing certificate/private key is not available in this Mac Keychain.' >&2; exit 1;
}
work="$(mktemp -d -t commoncopy-notary)"
mount=""
cleanup() {
  if [[ -n "$mount" ]]; then hdiutil detach "$mount" -quiet || true; fi
  rm -rf "$work"
}
trap cleanup EXIT
hdiutil verify "$input"
hdiutil attach -readonly -noverify -noautoopen -nobrowse -plist "$input" > "$work/attach.plist"
mount="$(python3 - "$work/attach.plist" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'rb') as stream:
    data = plistlib.load(stream)
print(next(item['mount-point'] for item in data['system-entities'] if 'mount-point' in item))
PY
)"
[[ -d "$mount/CommonCopy.app" && -s "$mount/.DS_Store" && -s "$mount/.background/installer.tiff" ]]
[[ "$(readlink "$mount/Applications")" == /Applications ]]
ditto "$mount" "$work/staging"
hdiutil detach "$mount" -quiet
mount=""
app="$work/staging/CommonCopy.app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
final="$output/CommonCopy-$version-macos-arm64-notarized.dmg"
[[ ! -e "$final" && ! -e "$final.sha256" ]] || { echo 'Output already exists; choose another output directory.' >&2; exit 1; }
record="$(mktemp -d "$output/notarization-$version.XXXXXX")"
bash "$root/scripts/sign-macos-app.sh" "$app"
# Verify that hardening still permits the packaged .NET runtime to start, using
# disposable data rather than the maintainer's saved phrases.
lipo -verify_arch arm64 "$app/Contents/MacOS/CommonCopyMac"
mkdir "$work/test-library"
printf '%s\n' '{"operation":"snapshot"}' | \
  "$app/Contents/Helpers/Core/CommonCopy.DesktopBridge" "$work/test-library" > "$work/bridge.json"
python3 - "$work/bridge.json" <<'PY'
import json, sys
with open(sys.argv[1]) as stream:
    result = json.load(stream)
if not result.get('ok'):
    raise SystemExit('The signed runtime smoke test failed; nothing was submitted to Apple.')
PY

submit() {
  local file="$1" label="$2" rc=0
  echo "Submitting $label to Apple. This may take several minutes."
  xcrun notarytool submit "$file" --keychain-profile "$profile" --wait --timeout 30m \
    --output-format json > "$record/$label.json" || rc=$?
  python3 - "$record/$label.json" "$record/$label.id" <<'PY'
import json, pathlib, sys
with open(sys.argv[1]) as stream:
    result = json.load(stream)
submission = result.get('id')
if submission:
    pathlib.Path(sys.argv[2]).write_text(submission + '\n')
print('Apple submission:', submission, 'status:', result.get('status', 'unknown'))
PY
  if [[ -s "$record/$label.id" ]]; then
    xcrun notarytool log "$(< "$record/$label.id")" --keychain-profile "$profile" \
      "$record/$label-log.json" || true
  fi
  # Both the command and Apple's final status must indicate success.
  [[ "$rc" == 0 ]] || { echo "Apple submission did not complete; see $record. Do not resubmit while in progress." >&2; return 1; }
  python3 - "$record/$label.json" <<'PY'
import json, sys
with open(sys.argv[1]) as stream:
    result = json.load(stream)
if result.get('status') != 'Accepted':
    raise SystemExit('Apple has not accepted this submission. No release will be produced.')
PY
}

# Staple the app before packaging so the dragged-out application also carries
# Apple's ticket, including when users are offline.
ditto -c -k --sequesterRsrc --keepParent "$app" "$work/CommonCopy.zip"
submit "$work/CommonCopy.zip" application
xcrun stapler staple "$app"
xcrun stapler validate "$app"
codesign --verify --deep --strict "$app"
spctl --assess --type execute --verbose=2 "$app"

# Retain the approved Finder layout, background, and Applications alias.
hdiutil create -quiet -volname 'CommonCopy Installer' -srcfolder "$work/staging" \
  -fs HFS+ -format UDZO -imagekey zlib-level=9 "$work/CommonCopy.dmg"
codesign --force --sign "$identity" --timestamp "$work/CommonCopy.dmg"
submit "$work/CommonCopy.dmg" installer
xcrun stapler staple "$work/CommonCopy.dmg"
xcrun stapler validate "$work/CommonCopy.dmg"
codesign --verify --strict "$work/CommonCopy.dmg"
spctl --assess --type open --context context:primary-signature --verbose=2 "$work/CommonCopy.dmg"
hdiutil verify "$work/CommonCopy.dmg"

# Verify the final packaged copy as well, without installing or launching it.
hdiutil attach -readonly -noverify -noautoopen -nobrowse -plist "$work/CommonCopy.dmg" > "$work/final.plist"
mount="$(python3 - "$work/final.plist" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'rb') as stream:
    data = plistlib.load(stream)
print(next(item['mount-point'] for item in data['system-entities'] if 'mount-point' in item))
PY
)"
[[ "$(readlink "$mount/Applications")" == /Applications ]]
[[ -s "$mount/.DS_Store" && -s "$mount/.background/installer.tiff" ]]
xcrun stapler validate "$mount/CommonCopy.app"
codesign --verify --deep --strict "$mount/CommonCopy.app"
spctl --assess --type execute --verbose=2 "$mount/CommonCopy.app"
hdiutil detach "$mount" -quiet
mount=""
cp "$work/CommonCopy.dmg" "$final"
shasum -a 256 "$final" > "$final.sha256"
echo "Verified notarized installer: $final"
echo "Apple submission records: $record"
echo 'Before publication, download-test on a Mac with Gatekeeper enabled and review Accessibility setup.'
