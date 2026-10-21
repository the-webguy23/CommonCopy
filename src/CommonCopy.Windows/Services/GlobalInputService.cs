using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Input;
using System.Windows.Interop;
using CommonCopy.Core.Models;
using CommonCopy.Windows.Infrastructure;

namespace CommonCopy.Windows.Services;

public sealed class ActivationRequestedEventArgs(nint targetWindow, Point cursorPosition) : EventArgs
{
    public nint TargetWindow { get; } = targetWindow;

    public Point CursorPosition { get; } = cursorPosition;
}

public sealed class GlobalInputService : IDisposable
{
    private const int HotKeyId = 0x504D;
    private readonly NativeMethods.HookProcedure mouseHookProcedure;
    private nint mouseHookHandle;
    private nint windowHandle;
    private HwndSource? windowSource;
    private AppSettings settings = new();
    private bool suppressRightClick;
    private nint pendingTargetWindow;
    private Point pendingCursorPosition;
    private bool disposed;

    public GlobalInputService()
    {
        mouseHookProcedure = HandleMouseHook;
    }

    public event EventHandler<ActivationRequestedEventArgs>? ActivationRequested;

    public string? HotKeyRegistrationError { get; private set; }

    public void Start(nint messageWindowHandle, AppSettings initialSettings)
    {
        if (windowHandle != nint.Zero)
        {
            throw new InvalidOperationException("The global input service is already running.");
        }

        windowHandle = messageWindowHandle;
        windowSource = HwndSource.FromHwnd(windowHandle)
            ?? throw new InvalidOperationException("Could not create a Windows message source.");
        windowSource.AddHook(HandleWindowMessage);

        var moduleHandle = NativeMethods.GetModuleHandle(null);
        mouseHookHandle = NativeMethods.SetWindowsHookEx(
            NativeMethods.WhMouseLl,
            mouseHookProcedure,
            moduleHandle,
            0);
        if (mouseHookHandle == nint.Zero)
        {
            throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not install the CommonCopy mouse hook.");
        }

        UpdateSettings(initialSettings);
    }

    public void UpdateSettings(AppSettings updatedSettings)
    {
        settings = updatedSettings;
        suppressRightClick = false;

        if (windowHandle == nint.Zero)
        {
            return;
        }

        NativeMethods.UnregisterHotKey(windowHandle, HotKeyId);
        HotKeyRegistrationError = null;

        if (!TryParseHotKey(settings.KeyboardShortcut, out var modifiers, out var virtualKey))
        {
            HotKeyRegistrationError = $"'{settings.KeyboardShortcut}' is not a supported keyboard shortcut.";
            return;
        }

        if (!NativeMethods.RegisterHotKey(
                windowHandle,
                HotKeyId,
                modifiers | NativeMethods.ModNoRepeat,
                virtualKey))
        {
            HotKeyRegistrationError = "The keyboard shortcut is already in use by another application.";
        }
    }

    public static (nint TargetWindow, Point CursorPosition) CaptureCurrentContext()
    {
        NativeMethods.GetCursorPos(out var nativePoint);
        return (
            NativeMethods.GetForegroundWindow(),
            new Point(nativePoint.X, nativePoint.Y));
    }

    public void Dispose()
    {
        if (disposed)
        {
            return;
        }

        disposed = true;
        if (windowHandle != nint.Zero)
        {
            NativeMethods.UnregisterHotKey(windowHandle, HotKeyId);
        }

        if (mouseHookHandle != nint.Zero)
        {
            NativeMethods.UnhookWindowsHookEx(mouseHookHandle);
            mouseHookHandle = nint.Zero;
        }

        windowSource?.RemoveHook(HandleWindowMessage);
        windowSource = null;
        windowHandle = nint.Zero;
        GC.SuppressFinalize(this);
    }

    private nint HandleMouseHook(int code, nint wordParameter, nint longParameter)
    {
        if (code >= 0 && settings.CtrlRightClickEnabled)
        {
            var message = unchecked((int)wordParameter);
            if (message == NativeMethods.WmRightButtonDown && IsControlPressed())
            {
                var hookData = Marshal.PtrToStructure<NativeMethods.MouseHookData>(longParameter);
                suppressRightClick = true;
                pendingTargetWindow = NativeMethods.GetForegroundWindow();
                pendingCursorPosition = new Point(hookData.Point.X, hookData.Point.Y);
                return 1;
            }

            if (message == NativeMethods.WmRightButtonUp && suppressRightClick)
            {
                suppressRightClick = false;
                ActivationRequested?.Invoke(
                    this,
                    new ActivationRequestedEventArgs(pendingTargetWindow, pendingCursorPosition));
                return 1;
            }
        }

        return NativeMethods.CallNextHookEx(mouseHookHandle, code, wordParameter, longParameter);
    }

    private nint HandleWindowMessage(
        nint handle,
        int message,
        nint wordParameter,
        nint longParameter,
        ref bool handled)
    {
        if (message == NativeMethods.WmHotKey && wordParameter == HotKeyId)
        {
            var context = CaptureCurrentContext();
            ActivationRequested?.Invoke(
                this,
                new ActivationRequestedEventArgs(context.TargetWindow, context.CursorPosition));
            handled = true;
        }

        return nint.Zero;
    }

    private static bool IsControlPressed() =>
        (NativeMethods.GetAsyncKeyState(NativeMethods.VkControl) & 0x8000) != 0;

    private static bool TryParseHotKey(string text, out uint modifiers, out uint virtualKey)
    {
        modifiers = 0;
        virtualKey = 0;
        var parts = text.Split('+', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (parts.Length < 2)
        {
            return false;
        }

        foreach (var modifier in parts[..^1])
        {
            if (modifier.Equals("Ctrl", StringComparison.OrdinalIgnoreCase) ||
                modifier.Equals("Control", StringComparison.OrdinalIgnoreCase))
            {
                modifiers |= NativeMethods.ModControl;
            }
            else if (modifier.Equals("Shift", StringComparison.OrdinalIgnoreCase))
            {
                modifiers |= NativeMethods.ModShift;
            }
            else if (modifier.Equals("Alt", StringComparison.OrdinalIgnoreCase))
            {
                modifiers |= NativeMethods.ModAlt;
            }
            else if (modifier.Equals("Win", StringComparison.OrdinalIgnoreCase) ||
                     modifier.Equals("Windows", StringComparison.OrdinalIgnoreCase))
            {
                modifiers |= NativeMethods.ModWin;
            }
            else
            {
                return false;
            }
        }

        if (modifiers == 0 || !Enum.TryParse<Key>(parts[^1], ignoreCase: true, out var key))
        {
            return false;
        }

        virtualKey = unchecked((uint)KeyInterop.VirtualKeyFromKey(key));
        return virtualKey != 0;
    }
}
