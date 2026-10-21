using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows;
using CommonCopy.Windows.Infrastructure;

namespace CommonCopy.Windows.Services;

public static class SelectedTextCaptureService
{
    private const ushort VirtualKeyControl = 0x11;
    private const ushort VirtualKeyC = 0x43;
    private static readonly TimeSpan CaptureTimeout = TimeSpan.FromMilliseconds(1500);

    public static async Task<string> CaptureAsync(nint targetWindow)
    {
        if (targetWindow == nint.Zero)
        {
            throw new InvalidOperationException("CommonCopy could not identify the application containing the selection.");
        }

        var (hadPreviousText, previousText) = TryReadTextClipboard();
        string? capturedText = null;

        try
        {
            NativeMethods.SetForegroundWindow(targetWindow);
            await Task.Delay(100);
            var sequenceBeforeCopy = NativeMethods.GetClipboardSequenceNumber();
            SendCopyShortcut();

            var stopwatch = Stopwatch.StartNew();
            while (stopwatch.Elapsed < CaptureTimeout)
            {
                await Task.Delay(50);
                var currentSequence = NativeMethods.GetClipboardSequenceNumber();
                if (currentSequence == sequenceBeforeCopy)
                {
                    continue;
                }

                capturedText = TryReadTextClipboard().Text;
                if (capturedText is not null)
                {
                    break;
                }
            }

            if (string.IsNullOrWhiteSpace(capturedText))
            {
                throw new InvalidOperationException(
                    "No highlighted text could be copied. Highlight selectable text in the original application and try again.");
            }

            return capturedText;
        }
        finally
        {
            if (hadPreviousText && previousText is not null)
            {
                try
                {
                    await SetClipboardTextWithRetryAsync(previousText);
                }
                catch (ExternalException)
                {
                    // Capturing succeeded or produced its own useful error. Restoring
                    // the previous text clipboard remains a best-effort operation.
                }
                catch (InvalidOperationException)
                {
                    // Another process may keep the clipboard locked after the copy.
                }
            }
        }
    }

    private static (bool HadText, string? Text) TryReadTextClipboard()
    {
        try
        {
            if (Clipboard.ContainsText(TextDataFormat.UnicodeText))
            {
                return (true, Clipboard.GetText(TextDataFormat.UnicodeText));
            }
        }
        catch (ExternalException)
        {
            // The clipboard can be unavailable briefly while another application owns it.
        }

        return (false, null);
    }

    private static void SendCopyShortcut()
    {
        var inputs = new[]
        {
            CreateKeyboardInput(VirtualKeyControl, keyUp: false),
            CreateKeyboardInput(VirtualKeyC, keyUp: false),
            CreateKeyboardInput(VirtualKeyC, keyUp: true),
            CreateKeyboardInput(VirtualKeyControl, keyUp: true),
        };

        var sent = NativeMethods.SendInput(
            unchecked((uint)inputs.Length),
            inputs,
            Marshal.SizeOf<NativeMethods.Input>());
        if (sent != (uint)inputs.Length)
        {
            throw new Win32Exception(Marshal.GetLastWin32Error(), "Windows did not accept the copy keystroke.");
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

        throw new InvalidOperationException("The previous text clipboard could not be restored.", lastException);
    }
}
