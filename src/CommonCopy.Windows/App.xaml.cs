using System.Windows;
using System.Windows.Interop;
using CommonCopy.Core.Models;
using CommonCopy.Core.Services;
using CommonCopy.Windows.Services;
using CommonCopy.Windows.Views;

namespace CommonCopy.Windows;

public partial class App : Application
{
    private JsonPhraseRepository? repository;
    private PhraseLibraryDocument? document;
    private MainWindow? managerWindow;
    private PhrasePopupWindow? popupWindow;
    private GlobalInputService? globalInput;
    private TrayIconService? trayIcon;
    private bool isExiting;

    protected override async void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        DispatcherUnhandledException += (_, args) =>
        {
            MessageBox.Show(
                $"CommonCopy encountered an unexpected error.\n\n{args.Exception.Message}",
                "CommonCopy",
                MessageBoxButton.OK,
                MessageBoxImage.Error);
            args.Handled = true;
        };

        try
        {
            repository = new JsonPhraseRepository();
            document = await repository.LoadAsync();
            AppearanceTheme.Apply(document.Settings.Appearance);
            if (e.Args.Contains("--enable-startup", StringComparer.OrdinalIgnoreCase))
            {
                document.Settings.StartWithWindows = true;
                await repository.SaveAsync(document);
            }

            managerWindow = new MainWindow(repository, document, ShowPopupFromManager, ApplySettings, RequestExit);
            managerWindow.DocumentReplaced += (_, args) =>
            {
                document = args.Document;
                ApplySettings();
            };
            managerWindow.Closing += (_, args) =>
            {
                if (!isExiting)
                {
                    args.Cancel = true;
                    managerWindow.Hide();
                }
            };
            MainWindow = managerWindow;

            var managerHandle = new WindowInteropHelper(managerWindow).EnsureHandle();
            globalInput = new GlobalInputService();
            globalInput.ActivationRequested += (_, args) =>
                Dispatcher.BeginInvoke(() => ShowPhrasePopup(args.TargetWindow, args.CursorPosition));
            globalInput.Start(managerHandle, document.Settings);

            trayIcon = new TrayIconService(
                () => Dispatcher.BeginInvoke(ShowManager),
                () => Dispatcher.BeginInvoke(ShowPopupFromManager),
                () => Dispatcher.BeginInvoke(RequestExit));

            StartupRegistrationService.SetEnabled(document.Settings.StartWithWindows);
            if (!e.Args.Contains("--startup", StringComparer.OrdinalIgnoreCase))
            {
                ShowManager();
            }
        }
        catch (Exception exception)
        {
            MessageBox.Show(
                $"CommonCopy could not start.\n\n{exception.Message}",
                "CommonCopy",
                MessageBoxButton.OK,
                MessageBoxImage.Error);
            Shutdown(-1);
        }
    }

    protected override void OnExit(ExitEventArgs e)
    {
        popupWindow?.Close();
        globalInput?.Dispose();
        trayIcon?.Dispose();
        base.OnExit(e);
    }

    private void ShowManager()
    {
        if (managerWindow is null)
        {
            return;
        }

        managerWindow.Show();
        if (managerWindow.WindowState == WindowState.Minimized)
        {
            managerWindow.WindowState = WindowState.Normal;
        }

        managerWindow.Activate();
        managerWindow.RefreshView();
    }

    private void ShowPopupFromManager()
    {
        var context = GlobalInputService.CaptureCurrentContext();
        ShowPhrasePopup(context.TargetWindow, context.CursorPosition);
    }

    private void ShowPhrasePopup(nint targetWindow, Point cursorPosition)
    {
        if (repository is null || document is null)
        {
            return;
        }

        if (popupWindow is { IsVisible: true })
        {
            popupWindow.Activate();
            return;
        }

        popupWindow = new PhrasePopupWindow(
            document,
            async phrase =>
            {
                var catalog = new PhraseCatalog(document);
                catalog.RecordUse(phrase);
                await repository.SaveAsync(document);
                managerWindow?.RefreshView();
                await ClipboardPasteService.PasteAsync(phrase.Text, targetWindow, document.Settings);
            },
            async () =>
            {
                var capturedText = await SelectedTextCaptureService.CaptureAsync(targetWindow);
                if (managerWindow is null)
                {
                    throw new InvalidOperationException("The phrase manager is not available.");
                }

                await managerWindow.AddCapturedPhraseAsync(capturedText);
            },
            ShowManager);
        popupWindow.Closed += (_, _) => popupWindow = null;
        popupWindow.ShowNear(cursorPosition);
    }

    private void ApplySettings()
    {
        if (document is null)
        {
            return;
        }

        globalInput?.UpdateSettings(document.Settings);
        AppearanceTheme.Apply(document.Settings.Appearance);
        StartupRegistrationService.SetEnabled(document.Settings.StartWithWindows);
    }

    private void RequestExit()
    {
        isExiting = true;
        popupWindow?.Close();
        managerWindow?.Close();
        Shutdown();
    }
}
