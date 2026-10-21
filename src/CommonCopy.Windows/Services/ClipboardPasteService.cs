using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Windows;
using CommonCopy.Core.Models;
using CommonCopy.Windows.Infrastructure;

namespace CommonCopy.Windows.Services;

public static class ClipboardPasteService
{
    private const ushort VirtualKeyControl = 0x11;
    private const ushort VirtualKeyV = 0x56;

    public static async Task PasteAsync(string text, nint targetWindow, AppSettings settings)
    {
        if (string.IsNullOrEmpty(text))
        {
            return;
        }

        string? previousText = null;
        var hadPreviousText = false;

        try
        {
            hadPreviousText = Clipboard.ContainsText(TextDataFormat.UnicodeText);
            if (hadPreviousText)
            {
                previousText = Clipboard.GetText(TextDataFormat.UnicodeText);
            }
        }
        catch (ExternalException)
        {
            // Another process may briefly own the clipboard. The selected phrase still takes priority.
        }

        await SetClipboardTextWithRetryAsync(text);
        await Task.Delay(settings.PasteDelayMilliseconds);

        if (targetWindow != nint.Zero)
        {
            NativeMethods.SetForegroundWindow(targetWindow);
            await Task.Delay(40);
        }

        var inputs = new[]
        {
            CreateKeyboardInput(VirtualKeyControl, keyUp: false),
            CreateKeyboardInput(VirtualKeyV, keyUp: false),
            CreateKeyboardInput(VirtualKeyV, keyUp: true),
            CreateKeyboardInput(VirtualKeyControl, keyUp: true),
        };

        var sent = NativeMethods.SendInput(
            unchecked((uint)inputs.Length),
            inputs,
            Marshal.SizeOf<NativeMethods.Input>());
        if (sent != (uint)inputs.Length)
        {
            throw new Win32Exception(Marshal.GetLastWin32Error(), "Windows did not accept the paste keystroke.");
        }

        if (!settings.RestoreTextClipboardAfterPaste)
        {
            return;
        }

        await Task.Delay(settings.ClipboardRestoreDelayMilliseconds);
        try
        {
            if (hadPreviousText && previousText is not null)
            {
                await SetClipboardTextWithRetryAsync(previousText);
            }
            // If the previous clipboard did not contain text, leave the selected
            // phrase in place rather than destroying unknown rich clipboard data.
        }
        catch (ExternalException)
        {
            // The paste succeeded; clipboard restoration is best effort.
        }
    }

    private static NativeMethods.Input CreateKeyboardInput(ushort virtualKey, bool keyUp) => new()
    {
        Type = NativeMethods.InputKeyboard,
        Data = new NativeMethods.InputUnion
        {
            Keyboard = new NativeMethods.KeyboardInput
            {
                VirtualKey = virtualKey,
                Flags = keyUp ? NativeMethods.KeyEventKeyUp : 0,
            },
        },
    };

    private static async Task SetClipboardTextWithRetryAsync(string text)
    {
        ExternalException? lastException = null;

        for (var attempt = 0; attempt < 5; attempt++)
        {
            try
            {
                Clipboard.SetText(text, TextDataFormat.UnicodeText);
                return;
            }
            catch (ExternalException exception)
            {
                lastException = exception;
                await Task.Delay(40 * (attempt + 1));
            }
        }

        throw new InvalidOperationException("The clipboard is busy. Please try again.", lastException);
    }
}
