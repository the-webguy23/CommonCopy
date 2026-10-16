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

Highlighted-text capture, login-at-startup, configurable shortcuts, modifier/right
click activation, and a dedicated compact popup. The shortcut opens the manager
in this build. No sync, accounts, telemetry, clipboard history, or secret storage.

## Build locally (contributors only)

Install .NET 10 and Xcode Command Line Tools, then from the repo root:

```bash
bash scripts/build-macos.sh arm64
open artifacts/macos-arm64/CommonCopy.app
```

The script runs core/bridge tests and smoke-tests the packaged helper using
disposable data. `x86_64` is accepted but is not the current device test target.
