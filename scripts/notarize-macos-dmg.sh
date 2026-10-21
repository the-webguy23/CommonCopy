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
if [[ -n "${COMMONCOPY_RESUME_WORK:-}" ]]; then
  work="$(cd "$COMMONCOPY_RESUME_WORK" && pwd)"
  [[ -f "$work/signed.ok" && -d "$work/staging/CommonCopy.app" ]] || {
    echo 'This is not a saved signing workspace.' >&2; exit 1;
  }
else
  work="$(mktemp -d "$output/notarization-work.XXXXXX")"
fi
record="$work/records"
mkdir -p "$record"
mount=""
cleanup() {
  if [[ -n "$mount" ]]; then hdiutil detach "$mount" -quiet || true; fi
  echo "Signing workspace and submission records preserved: $work"
}
trap cleanup EXIT
if [[ ! -f "$work/signed.ok" ]]; then
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
fi
app="$work/staging/CommonCopy.app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
final="$output/CommonCopy-$version-macos-arm64-notarized.dmg"
[[ ! -e "$final" && ! -e "$final.sha256" ]] || { echo 'Output already exists; choose another output directory.' >&2; exit 1; }
if [[ ! -f "$work/signed.ok" ]]; then
bash "$root/scripts/sign-macos-app.sh" "$app"
touch "$work/signed.ok"
fi
codesign --verify --deep --strict "$app"
# Inspect architecture without launching downloaded, not-yet-notarized code.
lipo -verify_arch arm64 "$app/Contents/MacOS/CommonCopyMac"

submit() {
  python3 "$root/scripts/notary-request.py" "$1" "$2" "$record" "$profile"
}

# Staple the app before packaging so the dragged-out application also carries
# Apple's ticket, including when users are offline.
if [[ -n "${COMMONCOPY_ACCEPTED_APP_SUBMISSION:-}" ]]; then
  python3 "$root/scripts/notary-request.py" "$work/CommonCopy.zip" application "$record" "$profile" \
    --existing-id "$COMMONCOPY_ACCEPTED_APP_SUBMISSION"
  # The original timeout removed the staging copy. Re-signing the same code can
  # restore the same cdhash despite a different CMS timestamp. Never assume this:
  # require every native architecture/hash to appear in Apple's accepted ticket.
  python3 "$root/scripts/verify-notary-ticket.py" "$app" "$record/application-log.json"
else
  if [[ ! -s "$record/application.id" ]]; then
    ditto -c -k --sequesterRsrc --keepParent "$app" "$work/CommonCopy.zip"
  fi
  submit "$work/CommonCopy.zip" application
fi
xcrun stapler staple "$app"
xcrun stapler validate "$app"
codesign --verify --deep --strict "$app"
spctl --assess --type execute --verbose=2 "$app"

# Launch only after Apple acceptance, stapling, and Gatekeeper assessment.
# The browser-downloaded DMG can carry quarantine onto this staging copy;
# exercising it earlier causes Gatekeeper to kill the helper before submission.
# Keep quarantine intact and test with disposable data, never the user library.
mkdir -p "$work/test-library"
printf '%s\n' '{"operation":"snapshot"}' | \
  "$app/Contents/Helpers/Core/CommonCopy.DesktopBridge" "$work/test-library" > "$work/bridge.json"
python3 - "$work/bridge.json" <<'PY'
import json, sys
with open(sys.argv[1]) as stream:
    result = json.load(stream)
if not result.get('ok'):
    raise SystemExit('The notarized runtime smoke test failed; no release will be produced.')
PY

# Retain the approved Finder layout, background, and Applications alias.
if [[ ! -s "$record/installer.id" ]]; then
  # An earlier packaging attempt may have left a file before submission.
  # Use a fresh unique path and record it for a later resume.
  package_dir="$(mktemp -d "$work/package.XXXXXX")"
  hdiutil create -quiet -volname 'CommonCopy Installer' -srcfolder "$work/staging" \
    -fs HFS+ -format UDZO -imagekey zlib-level=9 "$package_dir/CommonCopy.dmg"
  codesign --force --sign "$identity" --timestamp "$package_dir/CommonCopy.dmg"
  printf '%s\n' "$package_dir/CommonCopy.dmg" > "$record/installer-path.txt"
fi
installer="$(< "$record/installer-path.txt")"
submit "$installer" installer
xcrun stapler staple "$installer"
xcrun stapler validate "$installer"
codesign --verify --strict "$installer"
spctl --assess --type open --context context:primary-signature --verbose=2 "$installer"
hdiutil verify "$installer"

# Verify the final packaged copy as well, without installing or launching it.
hdiutil attach -readonly -noverify -noautoopen -nobrowse -plist "$installer" > "$work/final.plist"
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
cp "$installer" "$final"
shasum -a 256 "$final" > "$final.sha256"
echo "Verified notarized installer: $final"
echo "Apple submission records: $record"
echo 'Before publication, download-test on a Mac with Gatekeeper enabled and review Accessibility setup.'
