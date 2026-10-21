# CommonCopy macOS private review — 0.4.3

Apple Silicon (arm64); macOS 13 or later. No .NET installation is needed.
CI packages have ad-hoc signatures for review preparation. Sign and notarize
the exact new package using `docs/macos-signing.md` before real-device review
or distribution. The accepted 0.4.2 notarization does not cover new code.

## Installation and guided setup

1. Quit the previous CommonCopy using its application menu. Keep Application
   Support data; updates must preserve saved phrases and preferences.
2. Eject older CommonCopy Installer disks. Open the new, notarized DMG.
3. Drag CommonCopy to Applications; choose Replace for an update.
4. Open CommonCopy from Applications, then eject the installer.
5. With no Accessibility permission, the rounded setup card should appear
   before the manager. Choose Open Accessibility Settings, enable CommonCopy
   in Privacy & Security → Accessibility, and unlock settings if requested.
6. CommonCopy must open its manager automatically after access is enabled.
   Existing users with valid permission should go directly to the manager.

There is no Set up later or acceptance checkbox. Closing the setup card leaves
CommonCopy in the menu bar; reopening it returns to setup until access is
granted. Quit CommonCopy remains available. The MIT license is bundled with
the application and shown on the installer card; no additional contract or
acceptance records are collected.

If System Settings cannot open, follow the manual path displayed on the card.
If macOS retains a stale entry from an earlier ad-hoc build, quit CommonCopy,
remove that entry, add the installed application again, and enable it. A
properly signed/notarized release must not require a Terminal repair.

## Setup acceptance checks

- [ ] Fresh install without access: setup appears and explains all three actions.
- [ ] Open settings: correct pane opens, waiting status fits without clipping.
- [ ] Enable access: manager opens automatically; no restart or Continue click.
- [ ] Close setup and reopen through the menu bar: setup is still required.
- [ ] Attempt activation before granting: no phrase menu, paste, or capture.
- [ ] Permission already granted: launch directly into the manager.
- [ ] Revoke permission while running: manager hides and setup returns.
- [ ] Grant again: manager and activation work again.
- [ ] Launch the app from the mounted installer: installation instructions appear
      instead of asking for permission for that temporary app location.
- [ ] Light/Dark cards, long fallback text, approved transparent logo, rounded
      corners and controls all fit the MacBook display.

## Utility regression checks

- [ ] Command + right-click opens the compact menu near the pointer; normal
      right-click still belongs to the source application. Release Command
      before mouse-up and test two-finger secondary click as well.
- [ ] Command–Shift–Space opens the same compact menu. Closing the manager
      leaves the utility running; the menu-bar icon reopens it. Quit exits.
- [ ] Paste multiline/Unicode text into TextEdit, a browser, and another everyday
      app at the original caret. Clipboard restoration must not overwrite a
      newer copy made during the operation.
- [ ] Save highlighted text opens an editable draft containing the exact new
      selection. Choose an appropriate category and save: the manager hides
      automatically and focus returns to the source app. Cancel saves nothing.
- [ ] No selection, non-text input, or lost focus produces a clear error and
      never saves an old clipboard value.
- [ ] Add/edit/save a phrase: hide only after successful Save. Failed saves stay
      open. Test categories, nested Prompts → GPT, search, favourites, enable,
      duplicate, delete, ranking, export/import, and persistence after relaunch.
- [ ] Verify All Phrases and Selected Phrase preview in both appearances.
- [ ] Disable Command + right-click in Settings: ordinary right-click remains
      unchanged. Re-enable, quit, and relaunch to verify the preference.

Data: `~/Library/Application Support/CommonCopy/phrases.json`. The rotating
backup is `phrases.backup.json`; use Export for a lasting backup. No accounts,
sync, telemetry, background clipboard history, or keystroke recording.

## Validation and build

The maintainer confirmed 0.4.2 launches from its signed/notarized installer and
Command + right-click, paste, and selection capture work after enabling access.
The new guided setup needs a fresh real-device pass after signing 0.4.3.

On a Mac with .NET 10 and Xcode Command Line Tools, from the repository root:

```bash
bash scripts/build-macos.sh arm64
bash scripts/build-macos-dmg.sh artifacts/macos-arm64/CommonCopy.app
```

Build tests cover setup state transitions, blocked entry points, existing menu
and capture behavior, and live native input/clipboard fixtures where runner
permissions allow. CI records native setup views and screenshots of the packaged
app and Finder installer. Smoke tests install a unique disposable app beneath
the CI user's Applications directory and remove it afterward. They never edit
a tester's Accessibility permissions or library.
