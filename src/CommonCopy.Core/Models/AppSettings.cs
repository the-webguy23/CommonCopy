namespace CommonCopy.Core.Models;

public sealed class AppSettings
{
    // Persisted with the existing phrase library. Older libraries default to Light.
    public string Appearance { get; set; } = "Light";

    public bool CtrlRightClickEnabled { get; set; } = true;

    public string KeyboardShortcut { get; set; } = "Ctrl+Shift+Space";

    public bool StartWithWindows { get; set; }

    public bool RestoreTextClipboardAfterPaste { get; set; } = true;

    public int ClipboardRestoreDelayMilliseconds { get; set; } = 350;

    public int PasteDelayMilliseconds { get; set; } = 120;

    public int RecentPhraseLimit { get; set; } = 10;

    public double PopupWidth { get; set; } = 430;

    public bool ClosePopupWhenFocusIsLost { get; set; } = true;
}
