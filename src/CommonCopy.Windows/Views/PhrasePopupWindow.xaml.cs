using System.Collections.ObjectModel;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media;
using CommonCopy.Core.Models;
using CommonCopy.Core.Services;

namespace CommonCopy.Windows.Views;

public enum PopupNodeAction
{
    None,
    SaveHighlightedText,
}

public sealed class PopupNode
{
    public required string DisplayText { get; init; }

    public PhraseEntry? Phrase { get; init; }

    public PopupNodeAction Action { get; init; }

    public bool IsExpanded { get; init; }

    public ObservableCollection<PopupNode> Children { get; } = [];
}

public partial class PhrasePopupWindow : Window
{
    private readonly PhraseLibraryDocument document;
    private readonly Func<PhraseEntry, Task> phraseSelected;
    private readonly Func<Task> saveHighlightedText;
    private readonly Action managePhrases;
    private bool ready;
    private bool executingAction;

    public PhrasePopupWindow(
        PhraseLibraryDocument document,
        Func<PhraseEntry, Task> phraseSelected,
        Func<Task> saveHighlightedText,
        Action managePhrases)
    {
        InitializeComponent();
        this.document = document;
        this.phraseSelected = phraseSelected;
        this.saveHighlightedText = saveHighlightedText;
        this.managePhrases = managePhrases;
        Width = document.Settings.PopupWidth;
        ready = true;
        BuildTree();
        Loaded += (_, _) => SearchBox.Focus();
    }

    public void ShowNear(Point screenPosition)
    {
        Show();
        UpdateLayout();

        var dpi = VisualTreeHelper.GetDpi(this);
        var requestedLeft = screenPosition.X / dpi.DpiScaleX + 10;
        var requestedTop = screenPosition.Y / dpi.DpiScaleY + 10;
        var workArea = SystemParameters.WorkArea;
        Left = Math.Clamp(requestedLeft, workArea.Left, Math.Max(workArea.Left, workArea.Right - ActualWidth));
        Top = Math.Clamp(requestedTop, workArea.Top, Math.Max(workArea.Top, workArea.Bottom - ActualHeight));
        Activate();
    }

    private void BuildTree()
    {
        var catalog = new PhraseCatalog(document);
        var roots = new ObservableCollection<PopupNode>();
        var query = SearchBox.Text.Trim();

        roots.Add(new PopupNode
        {
            DisplayText = "＋ Save highlighted text…",
            Action = PopupNodeAction.SaveHighlightedText,
        });

        if (!string.IsNullOrWhiteSpace(query))
        {
            var resultRoot = new PopupNode { DisplayText = "Search results", IsExpanded = true };
            foreach (var phrase in catalog.Search(null, query).Where(phrase => phrase.IsEnabled).Take(100))
            {
                resultRoot.Children.Add(CreatePhraseNode(phrase));
            }

            if (resultRoot.Children.Count == 0)
            {
                resultRoot.Children.Add(new PopupNode { DisplayText = "No matching phrases" });
            }

            roots.Add(resultRoot);
            PhraseTree.ItemsSource = roots;
            return;
        }

        var favorites = catalog.GetFavorites();
        if (favorites.Count > 0)
        {
            var favoritesRoot = new PopupNode { DisplayText = "★ Favourites", IsExpanded = true };
            foreach (var phrase in favorites)
            {
                favoritesRoot.Children.Add(CreatePhraseNode(phrase));
            }

            roots.Add(favoritesRoot);
        }

        var commonlyUsed = catalog.GetCommonlyUsed();
        if (commonlyUsed.Count > 0)
        {
            var commonRoot = new PopupNode { DisplayText = "Commonly Used", IsExpanded = true };
            foreach (var phrase in commonlyUsed)
            {
                commonRoot.Children.Add(CreatePhraseNode(phrase));
            }

            roots.Add(commonRoot);
        }

        foreach (var category in catalog.GetChildCategories(null))
        {
            roots.Add(CreateCategoryNode(category, catalog));
        }

        PhraseTree.ItemsSource = roots;
    }

    private PopupNode CreateCategoryNode(PhraseCategory category, PhraseCatalog catalog)
    {
        var node = new PopupNode { DisplayText = category.Name };
        foreach (var phrase in catalog.GetEnabledPhrases(category.Id))
        {
            node.Children.Add(CreatePhraseNode(phrase));
        }

        foreach (var child in catalog.GetChildCategories(category.Id))
        {
            node.Children.Add(CreateCategoryNode(child, catalog));
        }

        return node;
    }

    private static PopupNode CreatePhraseNode(PhraseEntry phrase) => new()
    {
        DisplayText = phrase.Title,
        Phrase = phrase,
    };

    private async void PhraseTree_MouseLeftButtonUp(object sender, MouseButtonEventArgs e)
    {
        if (PhraseTree.SelectedItem is PopupNode node && CanExecute(node))
        {
            await ExecuteNodeAsync(node);
        }
    }

    private async void Window_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Escape)
        {
            Close();
            return;
        }

        if (e.Key == Key.Enter && PhraseTree.SelectedItem is PopupNode node && CanExecute(node))
        {
            e.Handled = true;
            await ExecuteNodeAsync(node);
        }
        else if (e.Key == Key.Down && SearchBox.IsKeyboardFocusWithin)
        {
            PhraseTree.Focus();
        }
    }

    private void SearchBox_TextChanged(object sender, System.Windows.Controls.TextChangedEventArgs e)
    {
        if (ready)
        {
            BuildTree();
        }
    }

    private void Manage_Click(object sender, RoutedEventArgs e)
    {
        Close();
        managePhrases();
    }

    private void Window_Deactivated(object sender, EventArgs e)
    {
        if (!executingAction && document.Settings.ClosePopupWhenFocusIsLost)
        {
            Close();
        }
    }

    private static bool CanExecute(PopupNode node) =>
        node.Phrase is not null || node.Action != PopupNodeAction.None;

    private async Task ExecuteNodeAsync(PopupNode node)
    {
        if (executingAction)
        {
            return;
        }

        executingAction = true;
        Close();
        try
        {
            if (node.Phrase is not null)
            {
                await phraseSelected(node.Phrase);
            }
            else if (node.Action == PopupNodeAction.SaveHighlightedText)
            {
                await saveHighlightedText();
            }
        }
        catch (Exception exception)
        {
            var operation = node.Action == PopupNodeAction.SaveHighlightedText
                ? "save the highlighted text"
                : "insert the phrase";
            MessageBox.Show(
                $"CommonCopy could not {operation}.\n\n{exception.Message}",
                "CommonCopy",
                MessageBoxButton.OK,
                MessageBoxImage.Error);
        }
    }
}
