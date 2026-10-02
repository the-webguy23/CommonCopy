using System.Runtime.ExceptionServices;
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
    public void ActualButtonAndSelectedItemTextIsWhite(string theme) => OnSta(() =>
    {
        var root = CreateRoot(theme);
        var button = new Button { Content = "Save" };
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
        AssertTextWhite(button, "Settings");
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
            Header = "Enabled", Binding = new System.Windows.Data.Binding("Enabled"),
            ElementStyle = (Style)root.FindResource("GridCheck"),
        });
        grid.Items.Add(new { Title = "Saved reply", Enabled = true });
        grid.SelectedIndex = 0;
        root.Children.Add(grid);
        Layout(root);

        AssertTextWhite(grid, "Saved reply");
        var check = Assert.Single(Descendants<CheckBox>(grid));
        Assert.True(check.IsChecked);
        Assert.False(check.IsHitTestVisible);
        Assert.Contains(Descendants<Border>(check), border => border.CornerRadius.TopLeft > 0);
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
