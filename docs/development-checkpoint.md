# CommonCopy development checkpoint

## 2026-10-16: compact Windows menu

Maintainer approved adapting the successful compact Mac menu to Windows.
Replace the large searchable tree popup with a native Windows shortcut menu:
Save highlighted text, Favourites, Commonly Used, nested category/phrase menus,
and Manage phrases. Preserve Ctrl + right-click and the configured hotkey.
Windows owns menu sizing, monitor placement, keyboard navigation and dismissal.
Search and editing remain in the existing manager. Old popup width/focus-loss
preferences are retained in JSON for compatibility, but hidden in Settings
because they do not control a native menu. Captured-text saves hide the manager
after successful persistence and return focus to the source.

Based independently on tested editorial branch 0e5be09; no Mac source or draft
PR is merged. Windows device checks, including multi-monitor/DPI, actual source
caret, ordinary right-click and trackpad behavior, remain acceptance gates.
Never merge any PR without maintainer instructions.

## 2026-10-16: approved modular utility redesign

Maintainer approved the monochrome modular website and the solid-C/dotted-copy
logo, and authorized redesign of both utilities. Windows is version 0.4.0; Mac
is 0.3.0. Existing compact native menus, Ctrl/Command-right-click, capture/paste
safeguards and data format are preserved. The manager uses category navigation,
search, a phrase list and selected-phrase actions; infrequent actions are grouped
in menus. Settings and library transfer are clearly separated. Both saved
appearance values remain compatible, now styled Light/Dark in monochrome.

Windows Add/Edit/Capture Save hides the manager after successful persistence.
The approved logo is an unchanged packaged Resource, used in the manager/window
and to derive the small tray representation. Source Git blob
43f93281b2e033e8d264758461c9d84a3e8843a7. Desktop remains local-only and ad-free.

Mac review happens immediately; Windows device acceptance is explicitly deferred
until Monday, October 19, when both devices are available. No PR merges or public
release are authorized. Automated window-render screenshots and contrast/search
checks supplement the native menu checks; they do not replace device workflows.
