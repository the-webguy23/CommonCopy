# CommonCopy development checkpoint

## Required acceptance gates — maintainer directive, 2026-10-16

The right-click workflow is the product's purpose, not optional follow-up scope.
Do not describe build/test success as complete user acceptance. Verify and report
each gate separately; keep both PRs unmerged until explicit instructions.

1. Download, installation/replacement, normal launch and relaunch. The private
   0.2.0 quarantine workaround is not a resolved distribution/installation issue.
   Public normal installation needs a Developer ID/notarization decision.
2. Command + right-click opens the pointer-positioned phrase menu, including
   nested categories, Favourites, Commonly Used, and Save highlighted text.
3. Capture selected text from another app into a reviewable editor; Save persists
   exactly once, Cancel does not persist, and stale clipboard text is rejected.
4. Choosing a saved phrase pastes into the original source field with appropriate
   Accessibility permission/focus handling and safe text clipboard restoration.
5. Ordinary right-click is untouched. Permission denial, toggle-off, modifier
   release, and repeated gestures must fail gracefully rather than disrupt input.
6. Phrases, hierarchy, preferences, counts, backups and import/export survive
   relaunch/update. Windows behavior and legacy migration stay intact.
7. Inspect both themes, management/editor/popup layout, selected text readability,
   and window sizing. Record observations; never promise perfect untested behavior.

CI can validate build, core/gesture/capture logic, startup, and screenshots.
Real-device acceptance is required for the actual input/focus/permission workflow.
Live system-workflow tests also run when the disposable CI Mac is Accessibility
trusted: a synthetic Command-right-click must reach the real event tap once, and
capture/paste must work against a separate fixed-text editor process with clipboard
restoration. These tests skip on non-CI or untrusted sessions rather than changing
any user's permissions. The fixture executable is never bundled in CommonCopy.app.

## 2026-10-16: first device launch and selection-capture follow-up

- Maintainer confirmed 0.2.0 launched on the M1 MacBook after clearing the
  quarantine flag for CommonCopy only. Open Anyway had repeatedly failed.
  Installed-copy `codesign --verify --deep --strict` passed. No system-wide
  Gatekeeper change was made; notarization remains a public-distribution gate.
- Maintainer then identified missing Save highlighted text. Version 0.2.1 adds
  the explicit capture action and prefilled editor, preserving Windows code and
  the shared storage format. See the current Mac checklist for device acceptance.
- Capture sends one Command-C after permission/focus checks, requires a fresh
  clipboard update, restores previous text when safe, and never saves on Cancel.
- New automated gates: isolated Swift capture-coordinator tests, core draft
  integrity tests, and a packaged-helper capture-draft protocol check.
- Local Release solution build passed with zero warnings/errors; all 25 core
  tests and all 14 executable-helper protocol checks passed. Current native
  test/build outcomes and exact package revision are recorded in draft PR #2.
- First-device capture, permission recovery, and supported-app tests remain for
  the maintainer; CI does not claim end-to-end cross-app capture acceptance.
- Before 0.2.1 delivery, the maintainer also identified Command + right-click as
  the most important activation path. Include it in the same update, opening a
  compact native phrase menu at the pointer with capture and nested categories.
  Preserve ordinary right-click, persist a Mac-only on/off preference, and keep
  Command–Shift–Space as the keyboard alternative. No keyboard stream is logged
  or monitored. Real event-tap/secondary-click acceptance remains pending.

## 2026-10-16: macOS foundation

- Maintainer tested Windows: "It works phenomenally."
- Further Windows UI polish deferred. PR #1 remains draft/unmerged; no explicit
  merge instruction was issued.
- Mac branch starts at tested `codex/editorial-themes` commit `0e5be09`.
- Device: MacBook Air M1 (2020), 16 GB; screenshot reports Golden Gate 27.0.
- Prompts and arbitrary nested subcategories already exist in the shared model
  and Windows editors. Preserve them in the Mac interface.
- Native SwiftUI/AppKit shell uses the shared core through a bundled local helper.
  See ADR 0002 and `macos-testing.md` for scope and remaining acceptance checks.
- Record automated build results and exact artifact commit before calling a Mac
  package ready. Real-device acceptance remains pending.
- No public release, notarization, paid enrollment, or merge authorized.

### Local validation and upload gate

- .NET 10.0.402: solution restored and Release build passed with zero warnings/errors.
- Core suite: 23 passed, zero failed/skipped (17 existing + 6 bridge tests).
- Executable helper protocol: 12 checks passed against disposable data.
- macOS plist, shell-script syntax, and whitespace checks passed.
- Native Swift/AppKit compilation and Mac device checks have not run. Linux
  cannot provide Apple's SDK. Windows WPF runtime checks require Windows CI.
- Automatic review initially blocked the source push. The maintainer explicitly
  approved pushing this branch to `the-webguy23/CommonCopy`, opening a draft PR,
  and running Windows/macOS CI on 2026-10-16. This authorization also covers
  necessary build fixes. Command-line Git lacked write authentication, so the
  authenticated GitHub connection uploaded the identical source tree.
- Draft PR #2: https://github.com/the-webguy23/CommonCopy/pull/2 ; base is
  `codex/editorial-themes`. PR #1 and main stay unmerged.
- Native arm64 compilation, all 23 core tests, signature verification, all 12
  packaged-helper protocol checks, and native launch passed at `9654146`.
  Windows Release build and all 28 tests (23 core + 5 WPF) also passed.
- First packaging failure: PDB symbols were treated as unsigned code in the
  helper directory. Packaging now omits development symbols; signatures pass.
- First native screenshot exposed a wrapped wordmark. Runtime refinement
  `269dd4b` keeps it on one line and expands the sidebar. CI captures Light and
  Dark startup screenshots for inspection before delivery.
- Final automated results and downloadable artifact are linked from PR #2.
  Real-Mac acceptance (Golden Gate 27.0, Accessibility, focus, paste, clipboard
  restoration, and everyday-app compatibility) remains pending maintainer tests.

## 2026-10-16: device acceptance and automatic dismissal

- Maintainer confirmed 0.2.1 Command + right-click, highlighted-text capture,
  save under Prompts, and insertion all succeeded on the MacBook. Activation
  worked after opening the manager and enabling the required permission.
- Open Anyway still looped for the replacement private build. The same
  app-specific quarantine workaround was needed; normal installation is not
  resolved by successful CI checks.
- Approved future installer: branded drag-to-install DMG with CommonCopy.app,
  Applications shortcut, clear drag guidance, and consistent Finder artwork and
  layout. Developer ID signing/notarization remain distribution gates; no paid
  enrollment or certificate purchase authorized.
- New request: save and get out of the way. Version 0.2.2 hides the manager only
  after successful phrase saving and editor dismissal, then restores the source
  app when available. It remains a menu-bar utility. Failed saves stay visible.
  Applies to captured and manually added/edited phrases. User device acceptance
  of this new behavior remains pending.

## 2026-10-16: approved utility redesign

Maintainer approved the monochrome modular website and solid-C/dotted-copy logo
and authorized redesign of both utilities. Mac will be reviewed immediately;
Windows device acceptance is deferred until Monday, October 19. Preserve native
compact menus, capture/paste safeguards, JSON data and automatic dismissal after
Save. PRs stay unmerged. The 0.2.2 Mac workflow including automatic window closing
passed device testing after the old Accessibility entry was removed and re-added.

Mac 0.3.0 groups settings/data transfer, simplifies the sidebar and phrase cards,
and moves infrequent phrase/category actions into menus. Light/Dark persisted
values remain compatible. Approved original logo is packaged unchanged and used
to derive standard app icon sizes. Source asset Git blob:
43f93281b2e033e8d264758461c9d84a3e8843a7. Desktop remains local-only and ad-free.


## 2026-10-16: Mac redesign accepted; installer implementation

Maintainer confirmed Mac 0.3.0 works fully on the MacBook, then authorized the
previously approved branded DMG installation flow. This is the tested Mac UI /
workflow baseline; Windows 0.4.0 physical review remains Monday October 19.

The installer uses a native Finder window, the approved logo unchanged,
monochrome artwork, the actual draggable application bundle and a real
/Applications symlink. A read-only compressed DMG carries Finder layout metadata.
Packaging tests verify the image, link, signature, byte-identical bundle copying
and launch from a copied bundle, with installer screenshots for visual review.
No phrase data or application runtime logic is changed by this packaging work.

This improves installation presentation. Private ad-hoc signing still requires
the known app-specific Gatekeeper repair on affected devices, and replacement
builds can require removal/re-addition of Accessibility permissions. Developer ID
signing/notarization remain public-release gates; no paid enrollment authorized.
PR #2 remains draft/unmerged. Actual DMG device acceptance is pending delivery.

The maintainer also requested the newly created SVG master be integrated during
installer work. Use Library CommonCopy_Approved_Logo.svg unchanged (contour
master, not the editable construction derivative). Mac manager and installer
load that SVG; native icon rasters are derived from it at packaging time.
