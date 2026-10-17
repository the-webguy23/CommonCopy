# CommonCopy macOS — first private test

Target: MacBook Air M1 (2020), 16 GB, macOS Golden Gate 27.0.
Package: Apple Silicon (`arm64`); minimum deployment target macOS 13.
This is a private ad-hoc signed prototype, not a notarized public release.

## Install

1. Extract the ZIP and move the entire `CommonCopy.app` to Applications.
2. Open it. The manager opens and a clipboard icon remains in the menu bar.
3. If macOS blocks this private build, use System Settings → Privacy & Security →
   Open Anyway for this app only. Do not disable Gatekeeper. If no app-specific
   option appears, report the exact message.
4. Closing the window leaves the menu-bar app running. Use Quit CommonCopy to exit.

No SDK, .NET install, account, or network connection is needed to run the package.

## Acceptance checklist

- [ ] Launch, close, reopen via menu-bar icon, then quit/relaunch.
- [ ] Verify Prompts, Code, Day-to-Day, Favourites, and Commonly Used.
- [ ] Select Prompts, Add category → GPT (parent Prompts). Add Image based and a
      project subcategory; save multiline/Unicode phrases inside each.
- [ ] Select Prompts and confirm descendant phrases appear.
- [ ] Edit/move/duplicate a phrase, toggle Favourite/Enabled, search title/body.
- [ ] Confirm disabled phrases cannot use the Copy/Paste action buttons.
- [ ] Switch both themes; check white button labels, rounded containers, selection,
      and readable inputs. Confirm persistence after quit/relaunch.
- [ ] Focus TextEdit in plain-text mode. Press Command–Shift–Space, choose Paste,
      grant Accessibility when requested, and retry. Check the original caret.
- [ ] Enable Command + right-click in the manager and grant Accessibility if
      requested. Return to CommonCopy, then focus TextEdit and Command-right-click:
      a compact menu must open near the pointer. Choose a phrase from a category
      submenu; it should paste at the source caret. Two-finger secondary click
      while Command is held should follow the same path.
- [ ] The menu must include Save highlighted text, Favourites, Commonly Used,
      nested categories (including Prompts → GPT), and Manage phrases.
- [ ] Ordinary right-click must open the source app's normal context menu. Test
      releasing Command before releasing the right button, and pressing Command
      only after an ordinary right-button down. No stray context-menu or double
      activation should appear. Disable the toggle and verify all right-clicks
      pass through; enable and quit/relaunch to verify the preference persists.
- [ ] Highlight text in TextEdit, press Command–Shift–Space, and choose Save
      highlighted text. Grant Accessibility if needed and retry. Verify the editor
      contains the exact selection and a generated title; choose a subcategory and
      Save. Cancel a second capture and verify no new phrase was saved.
- [ ] Test capture with no selection, non-text content, and permission denied.
      Expect an explanation, never a phrase created from an old clipboard value.
      Confirm previous plain-text clipboard restoration, and that a newer copy
      made during capture is not overwritten. Repeat in a browser/document app.
- [ ] Repeat in a browser text field and another everyday app.
- [ ] Deny Accessibility: manual Copy must work; failed Paste must not change the
      clipboard. Focus must be checked before sending Command-V.
- [ ] Copy ordinary text before pasting; check restoration. Copy something new
      during paste; CommonCopy must not overwrite it. Only text is restored.
- [ ] Confirm normal right-click is unchanged.
- [ ] Reuse phrases; check ranking by count then recency. Counts reflect copies
      and dispatched pastes, not confirmed acceptance by another app.
- [ ] Export/import a test library; check hierarchy, text, flags, counts, appearance.
- [ ] Invalid JSON import/category cycle must not damage saved data.
- [ ] Category deletion must warn about deleting its full subtree.

Data: `~/Library/Application Support/CommonCopy/phrases.json`.
Previous-version backup: `phrases.backup.json` in the same directory.
Use Export for a lasting backup; the automatic backup rotates on saves.

## Later milestones

Login-at-startup and configurable keyboard shortcuts. Command + right-click and
Command–Shift–Space open the compact native phrase menu. No sync, accounts,
telemetry, clipboard history, or secret storage.

## Build locally (contributors only)

Install .NET 10 and Xcode Command Line Tools, then from the repo root:

```bash
bash scripts/build-macos.sh arm64
open artifacts/macos-arm64/CommonCopy.app
```

The script runs core/bridge tests and smoke-tests the packaged helper using
disposable data. `x86_64` is accepted but is not the current device test target.

Version 0.2.1 adds Save highlighted text. It sends a single Command-C only after
that explicit action, verifies the source app's focus, waits for a new clipboard
change for up to 1.5 seconds, and opens an editable draft. Nothing is saved until
Save is chosen. This is selection capture, not background clipboard history.

Command + right-click uses a mouse-only event tap after Accessibility permission.
It checks Command on the mouse event, suppresses only the matching right-button
down/up pair, and opens the native menu at the pointer. No key stream is observed.
Without permission, keyboard activation remains available; paste and capture
still require Accessibility. Native menus follow macOS Light/Dark appearance.

For an update, Quit CommonCopy before replacing the app in Applications. Library
data stays in Application Support. This is still a private, non-notarized build;
real-device launch may require a per-app security exception. Developer ID signing
and notarization remain the proper public-distribution gate.

## Version 0.2.2: finish and get out of the way

After any successful phrase Save (captured text, Add phrase, or Edit phrase),
the editor dismisses and the manager hides automatically. CommonCopy stays in
the menu bar and returns focus to the remembered source application if it is
still running. Save errors keep the editor open; Cancel does not trigger the
successful-save behavior. Category and settings management remain available
until the user finishes them. Test a captured Save, a manual Add/Edit Save, an
invalid/failed Save, then reopen using the menu bar and Command + right-click.

## Version 0.3.0: approved modular redesign

White/black/gray UI with thin borders, filled and outlined controls, the approved
solid-C/dotted-copy logo and a clearer category/search/phrase layout. Category
options and phrase editing actions use small menus; Settings groups activation,
appearance and library transfer. Light/Dark still use the same stored values,
so existing data needs no migration. Native compact-menu activation is unchanged.

Update: Quit the old app, replace only CommonCopy.app in Applications, keep all
Application Support data. If blocked, the known private-build repair is:

```bash
xattr -dr com.apple.quarantine "/Applications/CommonCopy.app"
open "/Applications/CommonCopy.app"
```

If Command + right-click remains unavailable after an update, Quit CommonCopy,
remove its old Accessibility entry with the minus button, add the application
from Applications again, enable it, and reopen. Toggling the stale entry was
insufficient during 0.2.2 device testing; removal/re-addition restored access.
The private build still lacks stable Developer ID signing/notarization.

Check both appearances, Settings, category add/edit/delete/subcategories, phrase
options (edit/duplicate/favourite/enable/delete), search, Copy/Paste, capture,
Save auto-dismissal, cancel and failed saves. The 0.2.2 capture/save/auto-dismiss
workflow passed the maintainer's actual Mac test; the redesign needs a fresh
visual/workflow check.


## Branded DMG installation review

Open CommonCopy-0.3.0-macos-arm64.dmg. In the branded Finder window, drag the
CommonCopy application onto Applications. For an update, quit the running app
first and choose Replace. Open CommonCopy from Applications, then eject the
CommonCopy Installer disk. Do not run the utility from inside the disk image.
Saved phrases in Application Support must remain untouched.

Check the logo, instructions, real Applications shortcut and drag/copy behavior;
then confirm the installed app opens and Command + right-click, capture, Save
and automatic dismissal still work. The DMG does not remove the existing
private-signing/Gatekeeper or stale Accessibility-entry limitations documented
above. Developer ID/notarization are required before the intended public flow
can be considered complete.
