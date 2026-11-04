# Mobile acceptance checks

Record device/OS, build commit and result. Do not use personal phrase libraries for failure tests.

## Both platforms

- Fresh launch: default Prompts, Code and Day-to-Day categories; empty library is clear.
- Add, edit and delete phrases; favourite filtering and text/title search work. Force-quit/reopen and confirm persistence.
- Create a child category; its path and category filter are readable.
- Import `fixtures/desktop-library.json`. Verify the Unicode phrase is intact and hidden/disabled entries never appear in the keyboard. Export and import into the desktop utility; verify desktop settings survive.
- Attempt malformed, cyclic, duplicate-ID, future-schema and oversized imports; existing library remains intact.
- Open app and share UI at the same time, save separate phrases; neither save loses the other.
- Turn on airplane mode; library, capture and phrase insertion still work.
- Verify large text settings, portrait/landscape, small screens and light/dark device appearance.

## iOS/iPadOS

- Install a correctly signed app plus keyboard and Share extension with matching App Group entitlements.
- Enable keyboard with Full Access OFF. Read existing library and insert text in Notes, Safari and Messages; switch to next keyboard and hide keyboard.
- Change a phrase in app, return to the keyboard and insert the latest version. Delete or disable a phrase while keyboard is open; it must not insert stale text.
- Confirm secure fields and an app that rejects custom keyboards fall back to the system keyboard.
- Select plain text in Safari/Notes → Share → CommonCopy. Save, cancel, and test missing/URL-only input. Saved text remains exact, including newlines and emoji.
- Share extension invoked before first main-app launch initializes correctly.
- Lock/restart/unlock device; protected library access recovers after first unlock.
- Import/export via Files; cancel both pickers; no data changes on cancellation.
- Ensure keyboard doesn't request Full Access, make network requests, or read surrounding text. Usage count stays unchanged for iOS keyboard insertion, as documented.

## Android

- Test API 30 and a current Android device; verify system-bar/keyboard insets and navigation gestures.
- Enable CommonCopy keyboard, insert in browser/messaging/editor fields; switch back and delete an emoji with the keyboard delete button.
- Share plain text to CommonCopy; save and cancel.
- Highlight text in supporting apps → CommonCopy. Save selection; choose phrase to replace an editable selection; choose phrase on a read-only page and verify copying rather than modification.
- Another app with a custom selection toolbar may not expose the action; Share remains the fallback.
- Open the input-method panel, change library in the app and return; keyboard reloads new phrases.
- Import/export through Android's system document picker. No storage or network permission prompt is needed.
- Verify usage count updates only after successful insertion/copy, not just browsing.

## Before release

- Pass both build jobs and desktop baseline CI.
- Complete real-device checks above; record outstanding platform limitations.
- Review icon, keyboard height/tap targets, accessibility and setup wording with the maintainer.
- Configure distribution signing and privacy/store declarations separately. No release without maintainer approval.
