# Changelog

All notable changes will be documented here. This project follows Semantic Versioning once releases begin.

## [Unreleased]

### Fixed

- Added the missing xUnit namespace import required to compile the test project.
- Corrected the WPF About-menu event handler and phrase-editor property collision found during the first Windows build.
- Suppressed a WinForms-only DPI analyzer warning for the hybrid WPF tray application while retaining the WPF manifest settings.

### Added

- A **Save highlighted text…** action at the top of the system-wide popup. It copies an explicit selection from the previous application, generates a concise title, and opens a category-aware confirmation form before saving.
- Automated tests for captured-phrase title normalization and truncation.
- A one-command local release script that validates the solution and refreshes the installer, portable ZIP, checksums, and download website.
- Initial Windows-first repository and architecture.
- Local JSON phrase storage with validation, atomic replacement, and backup recovery.
- WPF phrase manager with categories, nested category selection, search, Favourites, Commonly Used, editing, duplication, deletion, and ordering.
- Tray icon, global hotkey, `Ctrl + Right Click` activation, popup phrase browser, and active-window paste service.
- Import/export, backup/restore, settings, and current-user startup registration.
- Core unit tests, Windows CI, installer definition, privacy documentation, and compatibility checklist.
- Static download website with responsive product pages, privacy details, sponsor inventory, and release-file synchronization.
