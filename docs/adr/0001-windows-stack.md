# ADR 0001: Windows MVP technology stack

- **Status:** Accepted
- **Date:** 2026-09-16

## Decision

Use .NET 10 LTS, WPF, and direct Windows APIs for the first CommonCopy implementation. Keep models and persistence in a platform-neutral core assembly. Store the initial phrase library as local JSON.

## Rationale

- WPF is mature, available without a paid runtime, and well suited to a small Windows tray utility.
- Direct `RegisterHotKey`, low-level mouse-hook, foreground-window, clipboard, and `SendInput` integration avoids a large automation dependency.
- A separate core assembly makes storage and catalog behavior easy to test.
- JSON keeps the MVP inspectable, portable, and easy to back up. The repository abstraction permits a future SQLite implementation without rewriting the UI.

## Consequences

- The UI is Windows-specific; a future macOS edition will require a separate native integration layer.
- WPF behavior must be tested on Windows, including focus, DPI, and application-integrity boundaries.
- JSON works well at MVP scale but is not optimized for very large libraries or concurrent writers.
