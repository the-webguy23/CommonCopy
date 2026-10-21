# CommonCopy Developer ID release

Status: Developer ID certificate is installed on the maintainer's Mac. Apple
accepted the application submission `20af6e54-a287-4401-8676-7f872bed3152`, confirmed
by the maintainer's notarytool info output on October 21, 2026. The original
0.4.2 device-review DMG is still ad-hoc signed. Ticket attachment, final DMG
notarization, and downloaded-app acceptance remain pending.

## One-time setup on the maintainer's Mac

1. Install and open Xcode. Sign in to the active paid Apple Developer account in
   Xcode Settings → Accounts (Apple Accounts in some versions). Select the paid
   team, choose Manage Certificates, then + → Developer ID Application. If that
   option is unavailable, use Apple's certificate website process below.
2. In Terminal, run `security find-identity -v -p codesigning`. There must be a
   valid `Developer ID Application: Your Name (TEAMID)` identity. Apple Development,
   Apple Distribution and Developer ID Installer are different certificates.
   Keep its private key in Keychain; do not paste passwords or export keys to chat.
3. Select the Xcode tools if necessary:
   `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`.
   `xcrun --find notarytool` and `xcrun --find stapler` must succeed.
4. Run `xcrun notarytool store-credentials "CommonCopy-notary"` and answer its
   prompts locally: Apple Account email, paid Team ID, and an app-specific password
   generated at <https://account.apple.com/> under Sign-In and Security.
   Credentials are validated and stored in the Mac Keychain. Do not send them to chat.

Website alternative: open <https://developer.apple.com/account/resources/certificates/list>,
choose + → Developer ID → Developer ID Application. Follow the Certificate
Assistant request process in Keychain Access on this same Mac, upload that CSR,
download the issued `.cer`, and double-click it to install. The private key must
remain paired with that certificate. Do not revoke an existing valid certificate
just to troubleshoot. Keep an encrypted backup of the signing identity privately.

## Sign the reviewed installer

Use the original, reviewed DMG, not the installed app with user-specific state.
From a checkout of this branch, run (replace the example identity and DMG path):

```bash
export COMMONCOPY_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)'
bash scripts/notarize-macos-dmg.sh "$HOME/Downloads/CommonCopy-0.4.2-macos-arm64.dmg"
```

This uses Apple tools and Python 3, with no Swift or .NET rebuild needed. It
modifies only a temporary copy, leaves Applications and saved phrases alone,
and preserves the approved drag-to-Applications design. No public release or
website publication occurs. Apple receives the app ZIP and signed DMG for scans.

All native .NET components are signed inside out with the same Developer ID and
secure timestamp. Hardened runtime is enabled; only the .NET helper executable
gets `allow-jit`. No sandbox or broad library-validation exceptions are added.
The app is notarized and stapled before the DMG is created; the signed DMG is then
notarized and stapled too. Apple status must be `Accepted` at both stages.
Signature, ticket, Gatekeeper and DMG checks must pass before the final file is
copied to `artifacts/notarized/`, alongside its checksum and submission records.

If Apple rejects a submission, the log in the printed records directory explains
the issue; do not distribute it. A first submission can take longer. If waiting
times out, use the recorded submission ID with `xcrun notarytool info ID
--keychain-profile CommonCopy-notary` to check status. Signed files and submission
IDs are now preserved under the printed signing workspace. Set
`COMMONCOPY_RESUME_WORK` to that exact workspace and rerun with the same input
and output arguments. Saved IDs are checked and reused; do not upload again.
The timeout response can have JSON on stderr and empty stdout; waiting and
status retrieval are separate operations, so this no longer causes a traceback.
Never mark a file approved based only on successful upload.

To recover the original accepted app after the older script removed its staging
copy, set `COMMONCOPY_ACCEPTED_APP_SUBMISSION` to the accepted ID and run against
the original reviewed DMG with the same signing identity. This restores signed
code and compares every native architecture and code-directory hash with Apple's
accepted ticket log. A mismatch stops packaging; there is no automatic fallback
upload. When all hashes match, attach Apple's ticket and continue to final DMG
submission. Only the final installer is newly submitted in this recovery mode.

## Final acceptance

Download the final DMG through a browser onto a test Mac with Gatekeeper enabled.
Open it, drag to Applications, launch without Terminal or Open Anyway, and test
Command-right-click, highlighted-text capture, paste and Save auto-dismissal.
Accessibility remains a separate macOS permission. Switching from the ad-hoc
build may require replacing its old Accessibility entry once. Check the MIT
notice, installer clarity, library preservation and uninstall behavior. The
separately planned guided Accessibility setup remains a product task, not a
side effect of signing. Retain Apple's submission IDs and final SHA-256 for
release traceability. Do not upload credentials, signing keys, or certificates
to GitHub or the website.

References:

- <https://developer.apple.com/help/account/certificates/create-developer-id-certificates/>
- <https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution>
- <https://developer.apple.com/documentation/security/customizing-the-notarization-workflow>
