# CommonCopy development guidance

## Product boundaries

- CommonCopy is a platform-neutral, local-only reusable-text utility. Windows is available and macOS is planned.
- Do not add accounts, cloud synchronization, advertising, analytics, or network calls to the desktop application without an explicit architectural decision.
- Never log keystrokes, clipboard contents, or phrase bodies.
- Do not treat the phrase library as encrypted secret storage.

## Architecture

- Keep platform-neutral models, validation, storage, and catalog behavior in `src/CommonCopy.Core`.
- Keep WPF and Win32 integration in `src/CommonCopy.Windows`.
- Preserve JSON schema compatibility or document and test migrations.
- Prefer built-in .NET and Windows capabilities over new dependencies.

## Required validation

For ordinary changes, run:

```powershell
dotnet restore CommonCopy.sln
dotnet build CommonCopy.sln --configuration Release --no-restore
dotnet test CommonCopy.sln --configuration Release --no-build
```

Changes to the tray icon, global hook, hotkey, popup, clipboard, foreground-window restoration, startup behavior, installer, or DPI handling also require the relevant checks in `docs/manual-test-checklist.md` on Windows.

## Safety

- Do not commit credentials, signing certificates, tokens, or production deployment secrets.
- Do not broaden Windows permissions or request elevation without a documented reason.
- Preserve normal right-click behavior unless the configured modifier is held.
- Keep external publishing, deployment, and releases behind explicit maintainer approval.
