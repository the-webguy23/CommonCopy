# Manual Windows compatibility checklist

Record the CommonCopy commit, Windows version, application version, privilege level, display scaling, and test result for every run.

## Installation and lifecycle

- [ ] Launch on a clean Windows 10 x64 profile.
- [ ] Launch on a clean Windows 11 x64 profile.
- [ ] Confirm one tray icon appears and no manager window opens unexpectedly.
- [ ] Open and hide the manager from the tray menu.
- [ ] Enable and disable start-with-Windows; verify the current-user Run entry.
- [ ] Exit from the tray menu and confirm hooks and hotkeys are removed.

## Activation

- [ ] Normal right-click remains unchanged without Ctrl.
- [ ] `Ctrl + Right Click` opens CommonCopy beside the pointer.
- [ ] The configured keyboard shortcut opens CommonCopy.
- [ ] Repeated activation does not create multiple popup windows.
- [ ] Popup placement remains on-screen at every monitor edge.
- [ ] Test 100%, 125%, 150%, and 200% display scaling.
- [ ] Test a mixed-DPI multi-monitor configuration.

## Paste targets

For each target, test short text, multiline text, Unicode, emoji, punctuation, URLs, code, and a phrase of at least 10,000 characters.

- [ ] Notepad
- [ ] Microsoft Word
- [ ] Outlook desktop compose window
- [ ] Gmail in Chrome
- [ ] Gmail in Edge
- [ ] Visual Studio Code
- [ ] Visual Studio
- [ ] Slack
- [ ] Discord
- [ ] A standard browser text input
- [ ] A browser content-editable field

## Highlighted-text capture

For each supported target, highlight text, open CommonCopy with `Ctrl + Right Click`, choose **Save highlighted text…**, review the generated title and category, save, and then paste the new phrase back into a text field.

- [ ] Notepad: single-line and multiline selection
- [ ] Microsoft Word
- [ ] Outlook desktop
- [ ] Chrome webpage text
- [ ] Edge webpage text
- [ ] A selectable PDF in the browser or a PDF reader
- [ ] Unicode, emoji, punctuation, and code indentation
- [ ] A selection of at least 10,000 characters
- [ ] Cancel the save dialog and confirm no phrase is created
- [ ] Invoke the action with no selection and confirm a useful error appears
- [ ] Confirm the previous text clipboard is restored after capture
- [ ] Confirm copy-protected or image-only PDF content fails safely

## Data and management

- [ ] In Settings, select Dark (Burnished Copper), save, and verify the manager, popup, phrase editor, category editor, and Settings use light, legible text and copper accents. Check selected rows, menus, dropdowns, search, and buttons.
- [ ] Restart and verify Dark persists. Switch to Light (Warm Editorial), verify all windows update, and restart again. Confirm an older library without the Appearance field opens in Light.

- [ ] Create, edit, duplicate, disable, favorite, reorder, and delete a phrase.
- [ ] Create a category and nested subcategory.
- [ ] Search by phrase title and body.
- [ ] Verify Favourites and Commonly Used update after insertion.
- [ ] Confirm Commonly Used ranks by use count and then most-recent use.
- [ ] Upgrade an existing PhraseMenu install with startup enabled. Confirm phrases, settings, and usage counts appear in CommonCopy, the old data directory stays intact, and the Run key has only CommonCopy.
- [ ] Launch CommonCopy when both data directories exist and confirm its existing library is preserved.
- [ ] Test installer and portable ZIP on Windows, including the renamed executable, startup toggle, and uninstall.
- [ ] Restart and confirm all data persists.
- [ ] Export data, edit the library, then import the export.
- [ ] Create and restore a backup.
- [ ] Confirm malformed imports are rejected without replacing current data.
- [ ] Confirm a corrupt primary file is preserved and a valid backup is recovered.

## Security and failure behavior

- [ ] Confirm no network traffic originates from the desktop process during normal use.
- [ ] Confirm ordinary keys and clicks are not written to disk.
- [ ] Test paste into a normally elevated application and document the integrity-level limitation.
- [ ] Test with clipboard text restoration enabled and disabled.
- [ ] Test when the clipboard is temporarily locked by another application.
- [ ] Confirm application errors show a useful message without exposing phrase contents.
