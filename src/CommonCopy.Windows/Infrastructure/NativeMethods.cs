using System.Runtime.InteropServices;

namespace CommonCopy.Windows.Infrastructure;

internal static class NativeMethods
{
    internal const int WhMouseLl = 14;
    internal const int WmRightButtonDown = 0x0204;
    internal const int WmRightButtonUp = 0x0205;
    internal const int WmHotKey = 0x0312;
    internal const int VkControl = 0x11;
    internal const uint InputKeyboard = 1;
    internal const uint KeyEventKeyUp = 0x0002;
    internal const uint ModAlt = 0x0001;
    internal const uint ModControl = 0x0002;
    internal const uint ModShift = 0x0004;
    internal const uint ModWin = 0x0008;
    internal const uint ModNoRepeat = 0x4000;

    internal delegate nint HookProcedure(int code, nint wordParameter, nint longParameter);

    [DllImport("user32.dll", SetLastError = true)]
    internal static extern nint SetWindowsHookEx(
        int hookId,
        HookProcedure callback,
        nint moduleHandle,
        uint threadId);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool UnhookWindowsHookEx(nint hookHandle);

    [DllImport("user32.dll")]
    internal static extern nint CallNextHookEx(
        nint hookHandle,
        int code,
        nint wordParameter,
        nint longParameter);

    [DllImport("user32.dll")]
    internal static extern short GetAsyncKeyState(int virtualKey);

    [DllImport("user32.dll")]
    internal static extern nint GetForegroundWindow();

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool SetForegroundWindow(nint windowHandle);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool GetCursorPos(out NativePoint point);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool RegisterHotKey(nint windowHandle, int id, uint modifiers, uint virtualKey);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool UnregisterHotKey(nint windowHandle, int id);

    [DllImport("user32.dll", SetLastError = true)]
    internal static extern uint SendInput(uint inputCount, Input[] inputs, int inputSize);

    [DllImport("user32.dll")]
    internal static extern uint GetClipboardSequenceNumber();

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    internal static extern nint GetModuleHandle(string? moduleName);

    [StructLayout(LayoutKind.Sequential)]
    internal struct NativePoint
    {
        internal int X;
        internal int Y;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct MouseHookData
    {
        internal NativePoint Point;
        internal uint MouseData;
        internal uint Flags;
        internal uint Time;
        internal nuint ExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct Input
    {
        internal uint Type;
        internal InputUnion Data;
    }

    [StructLayout(LayoutKind.Explicit)]
    internal struct InputUnion
    {
        [FieldOffset(0)]
        internal KeyboardInput Keyboard;

        [FieldOffset(0)]
        internal MouseInput Mouse;

        [FieldOffset(0)]
        internal HardwareInput Hardware;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct KeyboardInput
    {
        internal ushort VirtualKey;
        internal ushort ScanCode;
        internal uint Flags;
        internal uint Time;
        internal nuint ExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct MouseInput
    {
        internal int X;
        internal int Y;
        internal uint MouseData;
        internal uint Flags;
        internal uint Time;
        internal nuint ExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct HardwareInput
    {
        internal uint Message;
        internal ushort ParameterLow;
        internal ushort ParameterHigh;
    }
}
