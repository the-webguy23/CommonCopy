# CommonCopy development checkpoint

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
