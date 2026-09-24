# Architecture

## Goals

CommonCopy should be fast, local-first, understandable to contributors, and dependable in common Windows text fields. The initial design deliberately avoids accounts, cloud services, background network traffic, and a database.

## Components

```text
CommonCopy.Windows
  WPF manager and popup
  Tray icon
  Global mouse/hotkey listener
  Clipboard + SendInput paste bridge
  Explicit selected-text capture bridge
          |
          v
CommonCopy.Core
  Phrase/category models
  Catalog operations
  Validation
  Atomic JSON repository
          |
          v
%LOCALAPPDATA%\CommonCopy\phrases.json
```

### CommonCopy.Core

This platform-neutral assembly owns the persisted model, default data, catalog queries, validation, usage tracking, and JSON storage. It has no UI or Windows dependencies, which keeps most behavior independently testable.

### CommonCopy.Windows

This WPF executable owns Windows integration:

- `TrayIconService` exposes management, popup, and exit commands.
- `GlobalInputService` registers the configured keyboard hotkey and a low-level mouse hook. It suppresses right-click only while Ctrl is held and the feature is enabled.
- `PhrasePopupWindow` renders Favourites, commonly used phrases, and the category tree near the pointer.
- `ClipboardPasteService` records the previously focused window, places the selected phrase on the clipboard, restores focus, and sends Ctrl+V.
- `SelectedTextCaptureService` runs only after the user chooses **Save highlighted text…**. It restores the source window, sends Ctrl+C once, detects the resulting clipboard update, and returns the text to a prefilled phrase editor.
- `StartupRegistrationService` uses the current-user Run key and requires no administrator rights.

## Data lifecycle

The repository writes formatted JSON to a temporary file, copies the previous valid data file to `phrases.backup.json`, then atomically replaces the primary file. Invalid input is rejected before replacing current data. A corrupt primary file is preserved with a timestamp and the repository attempts backup recovery before creating defaults.

## Activation sequence

1. The global hook observes `Ctrl + Right Click`, or Windows delivers the configured hotkey.
2. CommonCopy captures the foreground window handle and pointer position.
3. The popup appears near the pointer.
4. The user either chooses an enabled phrase or chooses **Save highlighted text…**.
5. For insertion, CommonCopy records usage, saves data, restores the target window, and pastes.
6. For capture, CommonCopy restores the target window, copies the explicit selection, and opens a prefilled save dialog.

## Known risks

| Risk | Initial mitigation |
| --- | --- |
| Some elevated applications reject input from a non-elevated process | Document the Windows integrity-level limitation; do not request elevation by default |
| Clipboard formats beyond text are difficult to restore safely | Restore previous Unicode text only when configured; document the boundary |
| Global hooks can be perceived as keylogging | Listen only for the activation gesture; do not store input; document exact behavior |
| Application focus can change while the popup is open | Capture the foreground window at activation and restore it immediately before paste |
| Protected, image-only, or custom controls may reject copy | Use the standard Ctrl+C path and show a clear error without creating a phrase |
| Security software may flag unsigned binaries | Publish source and checksums; add code signing before stable releases |
| Windows APIs cannot be exercised in Linux development environments | Compile/test on Windows CI and maintain a real-device compatibility checklist |
