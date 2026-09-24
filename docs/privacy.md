# Privacy model

CommonCopy is designed to work without an account or network connection.

## Stored locally

- Phrase text, titles, categories, favourites, usage timestamps, and settings are stored in `%LOCALAPPDATA%\CommonCopy`.
- Export and backup files are created only at locations selected by the user.
- The MVP does not encrypt its local JSON file. Do not save credentials or secrets.

## Global input listener

The application installs a Windows low-level mouse hook so it can detect `Ctrl + Right Click` outside its own window. The hook checks only whether the right mouse button and Ctrl modifier form the activation gesture. It does not log, store, upload, or analyze clicks or typed text.

The alternative global keyboard shortcut is registered through `RegisterHotKey`; it does not require recording ordinary keystrokes.

## Clipboard

Selecting a phrase temporarily replaces the text clipboard and simulates Ctrl+V. Choosing **Save highlighted text…** explicitly returns focus to the previous application, simulates Ctrl+C once, and reads the copied text so it can be reviewed before saving. CommonCopy does not continuously inspect the clipboard or application content.

When the previous clipboard contained Unicode text, CommonCopy attempts to restore that text after either operation. Rich clipboard formats such as images and application-specific objects are not copied or retained by the initial implementation; when no previous text exists, the inserted or captured text remains on the clipboard. Clipboard contents are never transmitted.

## Network and telemetry

The desktop application contains no analytics, advertising, update checker, account system, or network client. Any future network feature must be opt-in, documented, and reviewed separately.
