using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Windows;
using CommonCopy.Core.Models;
using CommonCopy.Core.Services;

namespace CommonCopy.Windows.Views;

// Windows owns sizing, keyboard navigation, submenu placement, scrolling,
// dismissal and monitor/DPI positioning. The manager remains the search/editor UI.
public sealed class PhrasePopupMenu : IDisposable
{
    private readonly Dictionary<uint, Func<Task>> actions = [];
    private nint menu;
    private uint nextId = 1;
    private bool showing;
    private bool disposed;

    public PhrasePopupMenu(PhraseLibraryDocument document, Func<PhraseEntry, Task> paste,
        Func<Task> capture, Action manage)
    {
        menu = CreateMenu();
        try
        {
            AddAction(menu, "Save highlighted text…", capture);
            AddSeparator(menu);
            var catalog = new PhraseCatalog(document);
            AddPhraseGroup(menu, "Favourites", catalog.GetFavorites(), paste);
            AddPhraseGroup(menu, "Commonly Used", catalog.GetCommonlyUsed(), paste);
            AddSeparator(menu);
            foreach (var category in catalog.GetChildCategories(null))
            {
                AddCategory(menu, category, catalog, paste);
            }
            AddSeparator(menu);
            AddAction(menu, "Manage phrases…", () => { manage(); return Task.CompletedTask; });
        }
        catch { Dispose(); throw; }
    }

    public bool IsOpen => showing;

    internal nint MenuHandle => menu;

    public async Task ShowNearAsync(nint owner, Point screenPosition)
    {
        ObjectDisposedException.ThrowIf(disposed, this);
        if (showing) { return; }
        uint selected;
        showing = true;
        try
        {
            NativeMenu.SetForegroundWindow(owner);
            // Coordinates from the global hook are already physical screen pixels.
            // Respect the user's menu alignment setting, including RTL layouts.
            var alignment = NativeMenu.GetSystemMetrics(40) != 0 ? 0x0008u : 0u;
            selected = NativeMenu.TrackPopupMenuEx(menu, 0x0100u | 0x0002u | alignment,
                (int)screenPosition.X, (int)screenPosition.Y, owner, 0);
            NativeMenu.PostMessage(owner, 0, 0, 0);
        }
        finally { showing = false; }
        if (selected != 0 && actions.TryGetValue(selected, out var action))
        {
            await action();
        }
    }

    public void Close()
    {
        if (showing) { NativeMenu.EndMenu(); }
    }

    public void Dispose()
    {
        if (disposed) { return; }
        Close();
        disposed = true;
        if (menu != 0) { NativeMenu.DestroyMenu(menu); menu = 0; }
        actions.Clear();
        GC.SuppressFinalize(this);
    }

    private void AddCategory(nint parent, PhraseCategory category, PhraseCatalog catalog,
        Func<PhraseEntry, Task> paste)
    {
        var child = CreateMenu();
        try
        {
            foreach (var nested in catalog.GetChildCategories(category.Id))
            {
                AddCategory(child, nested, catalog, paste);
            }
            foreach (var phrase in catalog.GetEnabledPhrases(category.Id))
            {
                AddAction(child, phrase.Title, () => paste(phrase));
            }
            if (NativeMenu.GetMenuItemCount(child) == 0) { AddEmpty(child); }
            Append(parent, 0x0010, (nuint)child, Label(category.Name));
        }
        catch { NativeMenu.DestroyMenu(child); throw; }
    }

    private void AddPhraseGroup(nint parent, string title, IReadOnlyList<PhraseEntry> phrases,
        Func<PhraseEntry, Task> paste)
    {
        var child = CreateMenu();
        try
        {
            foreach (var phrase in phrases) { AddAction(child, phrase.Title, () => paste(phrase)); }
            if (phrases.Count == 0) { AddEmpty(child); }
            Append(parent, 0x0010, (nuint)child, title);
        }
        catch { NativeMenu.DestroyMenu(child); throw; }
    }

    private void AddAction(nint parent, string title, Func<Task> action)
    {
        var id = nextId++;
        actions.Add(id, action);
        Append(parent, 0, id, Label(title));
    }

    // Escape menu mnemonic syntax and control characters without changing stored titles.
    private static string Label(string text) => text.Replace("&", "&&").Replace('\t', ' ')
        .Replace('\r', ' ').Replace('\n', ' ');
    private static void AddEmpty(nint parent) => Append(parent, 0x0003, 0, "No phrases yet");
    private static void AddSeparator(nint parent) => Append(parent, 0x0800, 0, null);
    private static nint CreateMenu()
    {
        var handle = NativeMenu.CreatePopupMenu();
        return handle != 0 ? handle : throw new Win32Exception(Marshal.GetLastWin32Error());
    }
    private static void Append(nint parent, uint flags, nuint id, string? label)
    {
        if (!NativeMenu.AppendMenu(parent, flags, id, label))
        { throw new Win32Exception(Marshal.GetLastWin32Error()); }
    }

    private static class NativeMenu
    {
        [DllImport("user32.dll", SetLastError = true)] internal static extern nint CreatePopupMenu();
        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool AppendMenu(nint menu, uint flags, nuint id, string? text);
        [DllImport("user32.dll")] internal static extern int GetMenuItemCount(nint menu);
        [DllImport("user32.dll")] internal static extern uint TrackPopupMenuEx(nint menu, uint flags, int x, int y, nint owner, nint parameters);
        [DllImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] internal static extern bool DestroyMenu(nint menu);
        [DllImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] internal static extern bool EndMenu();
        [DllImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] internal static extern bool SetForegroundWindow(nint owner);
        [DllImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] internal static extern bool PostMessage(nint owner, uint message, nuint word, nint parameter);
        [DllImport("user32.dll")] internal static extern int GetSystemMetrics(int index);
    }
}
