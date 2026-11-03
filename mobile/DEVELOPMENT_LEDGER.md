# CommonCopy Mobile development ledger

## 2026-11-03 — Native mobile foundation, 0.1

Authorized scope: iPhone/iPad and Android phrase library; phrase keyboard on both platforms; Share capture on both; Android selected-text action where the host supports it.

Implementation lives under `mobile/` on `codex/mobile-commoncopy`, based on desktop main commit `9938bba68e534780d88372a96865ebae9f9daf6e`. No desktop implementation or production website changes are included.

Decisions:

- Native SwiftUI/UIKit on iOS and Android Java/platform UI. No cross-platform bridge, cloud backend or account system.
- Preserve desktop JSON schema 1 and desktop-only settings; manual file import/export instead of automatic sync.
- iOS app and Share extension coordinate mutations through an App Group. Keyboard reads only, requests no Full Access, and does not write usage counts.
- Android app/receiver/IME share one process and atomic-file store. The text action returns replacements only for editable selections; read-only sources copy phrases instead.
- Reuse approved CommonCopy icon assets and monochrome styling.
- Ship no store release from this branch. Simulator/debug outputs and real-device testing precede signed distribution.

Validation status is recorded in the pull request and CI runs. Real-device acceptance remains required; see `DEVICE_TESTS.md`.

Local validation completed:

- Android debug APK build: passed with Java 17 / SDK 36 / AGP 8.13.2.
- Android library unit tests: 8 passed, 0 failures.
- Android debug APK signature: verified (development key only).
- Swift library XCTest cases: 6 passed, 0 failures, compiled and run directly with Swift 6.2 on Linux. SwiftPM's subprocess path crashed in this environment; the same test methods were run through a direct XCTest runner.
- All iOS UI/extension sources: Swift syntax parse passed. UIKit/SwiftUI type checking and simulator build remain pending a Mac runner.
- Project YAML, Android XML and JSON fixtures: parsed successfully.
- Desktop .NET commands could not run here because dotnet/Windows are unavailable. No desktop sources changed.

Public branch push was blocked by automatic approval review pending explicit maintainer permission to publish mobile source. The local development commit and downloadable source package are the reviewable checkpoint. No mobile release, website edit, store upload or deployment occurred.

## Publication authorized

The maintainer explicitly approved publishing the development branch and opening a draft PR. The mobile source is now on `codex/mobile-commoncopy` with draft PR #5. Initial remote Android setup failed because its action attempted to install the retired SDK package `tools`; the workflow now requests only `platform-tools` and runs for PRs to avoid duplicate mobile jobs. Full build results follow in the PR.
