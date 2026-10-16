# CommonCopy development checkpoint

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
- Source is committed locally on `codex/macos-foundation`. Automatic approval
  review rejected the source push, citing external publication and AGENTS.md's
  explicit-maintainer-approval requirement. Do not retry or upload via a different
  tool without the user's authorization for this branch/repository.
- Next authorized step after approval: push this branch to
  `the-webguy23/CommonCopy`, open a draft PR targeting `codex/editorial-themes`,
  run Windows/macOS CI, fix build findings, and deliver the first private arm64
  package after passing. PR #1 and main stay unmerged.
