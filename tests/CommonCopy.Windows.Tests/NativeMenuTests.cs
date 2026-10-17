using System.IO;
using System.Runtime.ExceptionServices;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows;
using System.Windows.Interop;
using CommonCopy.Core.Models;
using CommonCopy.Windows.Views;
using Xunit;

namespace CommonCopy.Windows.Tests;

public sealed class NativeMenuTests
{
    [Fact]
    public void NativeMenuPreservesHierarchyRankingAndLiteralTitles()
    {
        var prompts = new PhraseCategory { Name = "Prompts" };
        var gpt = new PhraseCategory { Name = "GPT", ParentId = prompts.Id };
        var phrase = new PhraseEntry { Title = "R&D\t🧠", CategoryId = gpt.Id, Text = "Fixture", IsFavorite = true, UseCount = 2 };
        var doc = new PhraseLibraryDocument();
        doc.Categories.AddRange([prompts, gpt]);
        doc.Phrases.AddRange([phrase, new PhraseEntry { Title = "Hidden", CategoryId = gpt.Id, IsEnabled = false }]);
        using var menu = new PhrasePopupMenu(doc, _ => Task.CompletedTask, () => Task.CompletedTask, () => { });
        Assert.Equal(["Save highlighted text…", "", "Favourites", "Commonly Used", "", "Prompts", "", "Manage phrases…"], Labels(menu.MenuHandle));
        var categoryMenu = GetSubMenu(menu.MenuHandle, 5);
        Assert.Equal(["GPT"], Labels(categoryMenu));
        Assert.Equal(["R&&D 🧠"], Labels(GetSubMenu(categoryMenu, 0)));
        Assert.Equal(["R&&D 🧠"], Labels(GetSubMenu(menu.MenuHandle, 2)));
        var handle = menu.MenuHandle;
        menu.Dispose();
        Assert.False(IsMenu(handle));
    }

    [Fact]
    public void NativeMenuOpensAndCancelsRepeatedlyWithoutExecutingActions()
    {
        // Only the disposable CI desktop receives automated UI input/screenshots.
        if (Environment.GetEnvironmentVariable("GITHUB_ACTIONS") != "true") { return; }
        Exception? failure = null;
        var thread = new Thread(() =>
        {
            try
            {
                var actions = 0;
                var doc = new PhraseLibraryDocument();
                doc.Categories.Add(new PhraseCategory { Name = "Prompts" });
                using var menu = new PhrasePopupMenu(doc, _ => { actions++; return Task.CompletedTask; },
                    () => { actions++; return Task.CompletedTask; }, () => actions++);
                var host = new Window { Width = 1, Height = 1, Left = -100, Top = -100, ShowInTaskbar = false, WindowStyle = WindowStyle.None };
                host.Show();
                try
                {
                    var owner = new WindowInteropHelper(host).Handle;
                    for (var attempt = 0; attempt < 2; attempt++)
                    {
                        using var timer = new System.Threading.Timer(_ =>
                        {
                            try
                            {
                                if (attempt == 0)
                                {
                                    using var bitmap = new System.Drawing.Bitmap(1000, 700);
                                    using var graphics = System.Drawing.Graphics.FromImage(bitmap);
                                    graphics.CopyFromScreen(0, 0, 0, 0, bitmap.Size);
                                    var directory = Path.Combine(Environment.GetEnvironmentVariable("GITHUB_WORKSPACE")!, "artifacts", "menu-check");
                                    Directory.CreateDirectory(directory);
                                    bitmap.Save(Path.Combine(directory, "compact-windows-menu.png"), System.Drawing.Imaging.ImageFormat.Png);
                                }
                            }
                            catch (Exception error) { failure = error; }
                            finally { PostMessage(owner, 0x001F, 0, 0); }
                        }, null, 1500, Timeout.Infinite);
                        menu.ShowNearAsync(owner, new Point(400, 300)).GetAwaiter().GetResult();
                        Assert.False(menu.IsOpen);
                        Assert.Equal(0, actions);
                    }
                }
                finally { host.Close(); }
            }
            catch (Exception error) { failure = error; }
        });
        thread.IsBackground = true;
        thread.SetApartmentState(ApartmentState.STA);
        thread.Start();
        Assert.True(thread.Join(TimeSpan.FromSeconds(15)), "Native menu did not dismiss.");
        if (failure is not null) { ExceptionDispatchInfo.Capture(failure).Throw(); }
    }

    private static string[] Labels(nint menu) => Enumerable.Range(0, GetMenuItemCount(menu)).Select(index =>
    {
        var text = new StringBuilder(512);
        GetMenuString(menu, (uint)index, text, text.Capacity, 0x0400);
        return text.ToString();
    }).ToArray();

    [DllImport("user32.dll")] private static extern int GetMenuItemCount(nint menu);
    [DllImport("user32.dll")] private static extern nint GetSubMenu(nint menu, int index);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetMenuString(nint menu, uint item, StringBuilder text, int length, uint flags);
    [DllImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] private static extern bool IsMenu(nint menu);
    [DllImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] private static extern bool PostMessage(nint owner, uint message, nuint word, nint parameter);
}
