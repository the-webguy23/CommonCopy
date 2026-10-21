#!/bin/bash
set -euo pipefail
[[ "$(uname -s)" == Darwin ]] || { echo 'Signing requires macOS.' >&2; exit 1; }
app="${1:?Usage: sign-macos-app.sh /path/to/CommonCopy.app}"
[[ -d "$app" && ! -L "$app" ]] || { echo 'Expected an application bundle.' >&2; exit 1; }
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")" == com.commoncopy.desktop ]]
identity="${COMMONCOPY_SIGNING_IDENTITY:-}"
[[ "$identity" == 'Developer ID Application: '* ]] || {
  echo 'Set COMMONCOPY_SIGNING_IDENTITY to your Developer ID Application identity.' >&2; exit 1;
}
work="$(mktemp -d -t commoncopy-sign)"
trap 'rm -rf "$work"' EXIT
printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>' \
  '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
  '<plist version="1.0"><dict><key>com.apple.security.cs.allow-jit</key><true/></dict></plist>' \
  > "$work/core-entitlements.plist"
helper="$app/Contents/Helpers/Core/CommonCopy.DesktopBridge"
[[ -x "$helper" && -x "$app/Contents/MacOS/CommonCopyMac" ]]
# Sign from the inside out. Do not use --deep to sign, or grant JIT permission
# to the Swift shell. All native runtime libraries receive the same team ID.
while IFS= read -r -d '' binary; do
  if /usr/bin/file -b "$binary" | /usr/bin/grep -q 'Mach-O'; then
    if [[ "$binary" == "$helper" ]]; then
      codesign --force --sign "$identity" --timestamp --options runtime \
        --entitlements "$work/core-entitlements.plist" "$binary"
    else
      codesign --force --sign "$identity" --timestamp --options runtime "$binary"
    fi
  fi
done < <(find "$app/Contents/Helpers" -type f -print0)
codesign --force --sign "$identity" --timestamp --options runtime "$app"
codesign --verify --deep --strict --verbose=2 "$app"
codesign --display --verbose=4 "$app" 2> "$work/signature.txt"
grep -q 'flags=.*runtime' "$work/signature.txt"
grep -q '^Authority=Developer ID Application:' "$work/signature.txt"
grep -q '^Timestamp=' "$work/signature.txt"
echo 'Application and nested runtime signatures verified.'
