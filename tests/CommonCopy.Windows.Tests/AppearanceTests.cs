using System.Runtime.ExceptionServices;
using System.IO;
using System.Windows.Media.Imaging;
using CommonCopy.Core.Models;
using CommonCopy.Core.Services;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Xunit;

namespace CommonCopy.Windows.Tests;

public sealed class AppearanceTests
{
    [Theory]
    [InlineData("Light")]
    [InlineData("Dark")]
    public void FilledButtonsAndSelectedItemsKeepWhiteText(string theme) => OnSta(() =>
    {
        var root = CreateRoot(theme);
        var button = new Button { Content = "Save", Style = (Style)root.FindResource("PrimaryButton") };
        var list = new ListBox();
        list.Items.Add("Favourites");
        list.SelectedIndex = 0;
        var combo = new ComboBox();
        combo.Items.Add("Prompts");
        combo.SelectedIndex = 0;
        var tree = new TreeView();
        var node = new TreeViewItem { Header = new TextBlock { Text = "Code" }, IsSelected = true };
        tree.Items.Add(node);
        root.Children.Add(button);
        root.Children.Add(list);
        root.Children.Add(combo);
        root.Children.Add(tree);
        Layout(root);

        AssertTextWhite(button, "Save");
        AssertTextWhite(list, "Favourites");
        AssertTextWhite(combo, "Prompts");
        AssertTextWhite(tree, "Code");
    });

    [Fact]
    public void OpenControlsKeepWhiteTextWhenPaletteChanges() => OnSta(() =>
    {
        var root = CreateRoot("Light");
        var button = new Button { Content = "Settings" };
        var list = new ListBox();
        list.Items.Add("Day-to-Day");
        list.SelectedIndex = 0;
        root.Children.Add(button);
        root.Children.Add(list);
        Layout(root);
        var before = ((SolidColorBrush)button.Background).Color;

        root.Resources.MergedDictionaries[0] = Palette("Dark");
        Layout(root);

        Assert.NotEqual(before, ((SolidColorBrush)button.Background).Color);
        AssertTextColor(button, "Settings", ((SolidColorBrush)root.FindResource("TextBrush")).Color);
        AssertTextWhite(list, "Day-to-Day");
        root.Resources.MergedDictionaries[0] = Palette("Light");
        Layout(root);
        Assert.Equal(before, ((SolidColorBrush)button.Background).Color);
        AssertTextWhite(list, "Day-to-Day");
    });

    [Theory]
    [InlineData("Light")]
    [InlineData("Dark")]
    public void ReadOnlyPhraseGridUsesRoundedChecksAndWhiteSelectedText(string theme) => OnSta(() =>
    {
        var root = CreateRoot(theme);
        var grid = new DataGrid { AutoGenerateColumns = false, IsReadOnly = true, CanUserAddRows = false };
        grid.Columns.Add(new DataGridTextColumn { Header = "Title", Binding = new System.Windows.Data.Binding("Title") });
        grid.Columns.Add(new DataGridCheckBoxColumn
        {
            Header = "Enabled", Binding = new System.Windows.Data.Binding("IsEnabled"),
            ElementStyle = (Style)root.FindResource("GridCheck"),
        });
        grid.Items.Add(new CommonCopy.Core.Models.PhraseEntry { Title = "Saved reply", Text = "Reply text", IsEnabled = true });
        grid.SelectedIndex = 0;
        root.Children.Add(grid);
        Layout(root);

        AssertTextWhite(grid, "Saved reply");
        AssertTextColor(grid, "Title", ((SolidColorBrush)root.FindResource("TextBrush")).Color);
        AssertTextColor(grid, "Enabled", ((SolidColorBrush)root.FindResource("TextBrush")).Color);
        var check = Assert.Single(Descendants<CheckBox>(grid));
        Assert.True(check.IsChecked);
        Assert.False(check.IsHitTestVisible);
        Assert.Contains(Descendants<Border>(check), border => border.CornerRadius.TopLeft > 0);
    });

    [Fact]
    public void ActualManagerRendersBothAppearancesAndSearchesWithoutChangingLibrary() => OnSta(() =>
    {
        var app = new Application { ShutdownMode = ShutdownMode.OnExplicitShutdown };
        app.Resources.MergedDictionaries.Add(Palette("Light"));
        app.Resources.MergedDictionaries.Add(new ResourceDictionary
        {
            Source = new Uri("/CommonCopy;component/Themes/Controls.xaml", UriKind.Relative),
        });
        try
        {
            foreach (var theme in new[] { "Light", "Dark" })
            {
                app.Resources.MergedDictionaries[0] = Palette(theme);
                var prompts = new PhraseCategory { Name = "Prompts" };
                var gpt = new PhraseCategory { Name = "GPT", ParentId = prompts.Id };
                var document = new PhraseLibraryDocument();
                document.Categories.AddRange([prompts, gpt]);
                document.Phrases.AddRange([
                    new PhraseEntry { Title = "Draft a clear reply", Text = "Write a concise, friendly response to the message below.", CategoryId = gpt.Id, IsFavorite = true },
                    new PhraseEntry { Title = "Unicode example", Text = "Reusable text — ready when you are. 🧠", CategoryId = gpt.Id },
                ]);
                var repository = new JsonPhraseRepository(Path.Combine(Path.GetTempPath(), "CommonCopy-ui-" + Guid.NewGuid()));
                var window = new MainWindow(repository, document, () => { }, () => { }, () => { });
                using var tray = new CommonCopy.Windows.Services.TrayIconService(() => { }, () => { }, () => { });
                window.Show();
                try
                {
                    var search = (TextBox)window.FindName("SearchBox");
                    var grid = (DataGrid)window.FindName("PhraseGrid");
                    Assert.Equal(2, grid.Items.Count);
                    search.Text = "Unicode";
                    Assert.Single(grid.Items.Cast<object>());
                    search.Text = "";
                    grid.SelectedIndex = 0;
                    window.Dispatcher.Invoke(() => { }, System.Windows.Threading.DispatcherPriority.ApplicationIdle);
                    window.UpdateLayout();
                    Assert.True(grid.Columns[1].ActualWidth >= 160);
                    Assert.True(grid.Columns[2].ActualWidth >= 220);
                    Assert.Equal(((SolidColorBrush)app.FindResource("AppBackgroundBrush")).Color, ((SolidColorBrush)window.Background).Color);
                    Assert.Equal(((SolidColorBrush)app.FindResource("TextBrush")).Color, ((SolidColorBrush)window.Foreground).Color);
                    Assert.Equal(5, ((ListBox)window.FindName("CategoryList")).Items.Count);
                    Assert.NotNull(window.Icon);
                    Assert.False(File.Exists(repository.DataPath));
                    if (Environment.GetEnvironmentVariable("GITHUB_ACTIONS") == "true")
                    {
                        var bitmap = new RenderTargetBitmap((int)window.ActualWidth, (int)window.ActualHeight, 96, 96, PixelFormats.Pbgra32);
                        bitmap.Render(window);
                        var encoder = new PngBitmapEncoder(); encoder.Frames.Add(BitmapFrame.Create(bitmap));
                        var directory = Path.Combine(Environment.GetEnvironmentVariable("GITHUB_WORKSPACE")!, "artifacts", "menu-check");
                        Directory.CreateDirectory(directory);
                        using var stream = File.Create(Path.Combine(directory, $"manager-{theme.ToLowerInvariant()}.png"));
                        encoder.Save(stream);
                    }
                }
                finally { window.Close(); }
            }
        }
        finally { app.Shutdown(); }
    });

    private static StackPanel CreateRoot(string theme)
    {
        var root = new StackPanel();
        root.Resources.MergedDictionaries.Add(Palette(theme));
        root.Resources.MergedDictionaries.Add(new ResourceDictionary
        {
            Source = new Uri("/CommonCopy;component/Themes/Controls.xaml", UriKind.Relative),
        });
        return root;
    }

    private static ResourceDictionary Palette(string theme) => new()
    {
        Source = new Uri($"/CommonCopy;component/Themes/{theme}.xaml", UriKind.Relative),
    };

    private static void Layout(FrameworkElement root)
    {
        root.Measure(new Size(800, 1000));
        root.Arrange(new Rect(0, 0, 800, 1000));
        root.UpdateLayout();
    }

    private static void AssertTextWhite(DependencyObject root, string text)
    {
        var label = Assert.Single(Descendants<TextBlock>(root), block => block.Text == text);
        Assert.Equal(Colors.White, ((SolidColorBrush)label.Foreground).Color);
    }

    private static void AssertTextColor(DependencyObject root, string text, Color color)
    {
        var label = Assert.Single(Descendants<TextBlock>(root), block => block.Text == text);
        Assert.Equal(color, ((SolidColorBrush)label.Foreground).Color);
    }

    private static IEnumerable<T> Descendants<T>(DependencyObject root) where T : DependencyObject
    {
        for (var index = 0; index < VisualTreeHelper.GetChildrenCount(root); index++)
        {
            var child = VisualTreeHelper.GetChild(root, index);
            if (child is T match) yield return match;
            foreach (var descendant in Descendants<T>(child)) yield return descendant;
        }
    }

    private static void OnSta(Action action)
    {
        Exception? failure = null;
        var thread = new Thread(() =>
        {
            try { action(); }
            catch (Exception error) { failure = error; }
        });
        thread.SetApartmentState(ApartmentState.STA);
        thread.Start();
        Assert.True(thread.Join(TimeSpan.FromSeconds(30)), "WPF appearance check timed out.");
        if (failure is not null) ExceptionDispatchInfo.Capture(failure).Throw();
    }
}
