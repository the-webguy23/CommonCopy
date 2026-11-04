#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
[[ "$(uname -s)" == Darwin ]] || { echo 'Run this signing package on your Mac.' >&2; exit 1; }
input="$root/CommonCopy-0.4.3-macos-x86_64.dmg"
[[ -f "$input" ]] || { echo 'Keep this script inside the supplied signing package.' >&2; exit 1; }
identities=()
while IFS= read -r identity; do
  identities+=("$identity")
done < <(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p')
if [[ ${#identities[@]} -eq 0 ]]; then
  echo 'No usable Developer ID Application certificate/private key was found.'
  echo 'Use the same Mac and Developer ID certificate used for the desktop release.'
  exit 1
elif [[ ${#identities[@]} -eq 1 ]]; then
  export COMMONCOPY_SIGNING_IDENTITY="${identities[0]}"
else
  echo 'Choose the CommonCopy Developer ID Application certificate:'
  PS3='Certificate number: '
  select identity in "${identities[@]}"; do
    if [[ -n "$identity" ]]; then export COMMONCOPY_SIGNING_IDENTITY="$identity"; break; fi
  done
fi
export COMMONCOPY_NOTARY_PROFILE="${COMMONCOPY_NOTARY_PROFILE:-CommonCopy-notary}"
echo "Signing with: $COMMONCOPY_SIGNING_IDENTITY"
echo 'The certificate and credentials remain in your Mac Keychain.'
echo 'The app and installer will be submitted to Apple for notarization.'
bash "$root/scripts/notarize-macos-dmg.sh" "$input" "$root/Signed"
