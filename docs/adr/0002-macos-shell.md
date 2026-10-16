# ADR 0002: Native macOS shell with the shared phrase engine

- **Status:** Implemented for private prototype testing; runtime acceptance pending
- **Date:** 2026-10-16
- **Base checkpoint:** Windows appearance branch, `0e5be09`

## Decision

Use SwiftUI and AppKit for macOS. Bundle a self-contained .NET 10 helper that
references `CommonCopy.Core`. Swift sends one JSON request over stdin and reads
a JSON response over stdout. Each operation starts a helper process; there is
no network listener, shell interpolation, account, or clipboard collection.

The native shell supplies standard Mac windows, text editing, file dialogs,
menu-bar integration, and Core Graphics paste support without a third-party UI
framework. The helper preserves the existing validator, atomic repository,
backups, nested categories, Favourites, and Commonly Used ranking. Users need
no .NET install. Windows UI/integration and shared-core code remain unchanged.

## Boundaries

- The helper serializes processes with an exclusive file lease before loading
  the current library. Rejected mutations do not save.
- Data: `~/Library/Application Support/CommonCopy/phrases.json`.
- Imported Windows settings are preserved. Windows startup/activation settings
  are not executed on macOS. The initial Mac hotkey is Command–Shift–Space.
- macOS 13 is the compile-time minimum; Apple Silicon is the packaged target.
  Golden Gate 27.0 on the user's M1 requires real-device testing.
- Accessibility is requested only on explicit Paste. Copy works without it.
  Carbon hotkey registration avoids a general keyboard event monitor.
- Clipboard restoration restores previous text only, and only if its change
  count still matches our write. Rich formats are not restored.
- Counts reflect explicit copies/dispatched pastes, not confirmed insertion.
- Process startup and full snapshots should be measured on the real Mac before
  optimizing. There is no persistent helper supervision in this milestone.

## Later gates

Highlighted-text capture, configurable hotkey, modifier/right-click activation,
login-at-startup, and a dedicated compact popup remain subsequent milestones.
Normal right-click behavior is untouched. Do not claim full Windows parity.

Ad-hoc signing is for private builds. Developer ID signing, notarization, public
distribution, and paid enrollment require separate decisions. Do not disable
Gatekeeper globally. CI compilation and helper smoke tests do not substitute
for user acceptance of paste, focus, Accessibility, appearance, or launch.
