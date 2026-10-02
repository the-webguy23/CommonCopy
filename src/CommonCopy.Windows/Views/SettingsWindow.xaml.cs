using System.Windows;
using CommonCopy.Core.Models;

namespace CommonCopy.Windows.Views;

public partial class SettingsWindow : Window
{
    public SettingsWindow(AppSettings settings)
    {
        InitializeComponent();
        LightThemeBox.IsChecked = settings.Appearance != "Dark";
        DarkThemeBox.IsChecked = settings.Appearance == "Dark";
        CtrlRightClickBox.IsChecked = settings.CtrlRightClickEnabled;
        ShortcutBox.Text = settings.KeyboardShortcut;
        StartupBox.IsChecked = settings.StartWithWindows;
        RestoreClipboardBox.IsChecked = settings.RestoreTextClipboardAfterPaste;
        RecentLimitBox.Text = settings.RecentPhraseLimit.ToString();
        PopupWidthBox.Text = settings.PopupWidth.ToString("0");
        PasteDelayBox.Text = settings.PasteDelayMilliseconds.ToString();
        ClipboardDelayBox.Text = settings.ClipboardRestoreDelayMilliseconds.ToString();
        CloseOnFocusLossBox.IsChecked = settings.ClosePopupWhenFocusIsLost;
    }

    public bool CtrlRightClickEnabled { get; private set; }

    public string Appearance { get; private set; } = "Light";

    public string KeyboardShortcut { get; private set; } = string.Empty;

    public bool StartWithWindows { get; private set; }

    public bool RestoreClipboard { get; private set; }

    public int RecentLimit { get; private set; }

    public double PopupWidth { get; private set; }

    public int PasteDelay { get; private set; }

    public int ClipboardDelay { get; private set; }

    public bool CloseOnFocusLoss { get; private set; }

    public void ApplyTo(AppSettings settings)
    {
        settings.Appearance = Appearance;
        settings.CtrlRightClickEnabled = CtrlRightClickEnabled;
        settings.KeyboardShortcut = KeyboardShortcut;
        settings.StartWithWindows = StartWithWindows;
        settings.RestoreTextClipboardAfterPaste = RestoreClipboard;
        settings.RecentPhraseLimit = RecentLimit;
        settings.PopupWidth = PopupWidth;
        settings.PasteDelayMilliseconds = PasteDelay;
        settings.ClipboardRestoreDelayMilliseconds = ClipboardDelay;
        settings.ClosePopupWhenFocusIsLost = CloseOnFocusLoss;
    }

    private void Save_Click(object sender, RoutedEventArgs e)
    {
        var shortcut = ShortcutBox.Text.Trim();
        if (string.IsNullOrWhiteSpace(shortcut) || !shortcut.Contains('+'))
        {
            ShowValidationMessage("Enter a shortcut such as Ctrl+Shift+Space.");
            return;
        }

        if (!int.TryParse(RecentLimitBox.Text, out var recentLimit) || recentLimit is < 1 or > 100)
        {
            ShowValidationMessage("Commonly Used limit must be between 1 and 100.");
            return;
        }

        if (!double.TryParse(PopupWidthBox.Text, out var popupWidth) || popupWidth is < 280 or > 1_200)
        {
            ShowValidationMessage("Popup width must be between 280 and 1200.");
            return;
        }

        if (!int.TryParse(PasteDelayBox.Text, out var pasteDelay) || pasteDelay is < 0 or > 5_000)
        {
            ShowValidationMessage("Paste delay must be between 0 and 5000 milliseconds.");
            return;
        }

        if (!int.TryParse(ClipboardDelayBox.Text, out var clipboardDelay) || clipboardDelay is < 100 or > 10_000)
        {
            ShowValidationMessage("Clipboard restore delay must be between 100 and 10000 milliseconds.");
            return;
        }

        CtrlRightClickEnabled = CtrlRightClickBox.IsChecked == true;
        Appearance = DarkThemeBox.IsChecked == true ? "Dark" : "Light";
        KeyboardShortcut = shortcut;
        StartWithWindows = StartupBox.IsChecked == true;
        RestoreClipboard = RestoreClipboardBox.IsChecked == true;
        RecentLimit = recentLimit;
        PopupWidth = popupWidth;
        PasteDelay = pasteDelay;
        ClipboardDelay = clipboardDelay;
        CloseOnFocusLoss = CloseOnFocusLossBox.IsChecked == true;
        DialogResult = true;
    }

    private static void ShowValidationMessage(string message) => MessageBox.Show(
        message,
        "CommonCopy settings",
        MessageBoxButton.OK,
        MessageBoxImage.Information);
}
