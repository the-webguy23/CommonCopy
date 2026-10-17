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
