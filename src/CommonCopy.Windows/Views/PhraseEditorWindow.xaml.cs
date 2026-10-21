using System.Windows;
using CommonCopy.Core.Models;

namespace CommonCopy.Windows.Views;

public partial class PhraseEditorWindow : Window
{
    public PhraseEditorWindow(
        IReadOnlyList<CategoryListItem> categories,
        PhraseEntry? phrase,
        Guid selectedCategoryId,
        string? windowTitle = null)
    {
        InitializeComponent();
        if (!string.IsNullOrWhiteSpace(windowTitle))
        {
            Title = windowTitle;
        }

        CategoryBox.ItemsSource = categories;
        CategoryBox.SelectedItem = categories.FirstOrDefault(category => category.Id == selectedCategoryId) ?? categories.FirstOrDefault();
        TitleBox.Text = phrase?.Title ?? string.Empty;
        TextBox.Text = phrase?.Text ?? string.Empty;
        FavoriteBox.IsChecked = phrase?.IsFavorite ?? false;
        EnabledBox.IsChecked = phrase?.IsEnabled ?? true;
        Loaded += (_, _) =>
        {
            TitleBox.Focus();
            TitleBox.SelectAll();
        };
    }

    public string PhraseTitle { get; private set; } = string.Empty;

    public string PhraseText { get; private set; } = string.Empty;

    public Guid CategoryId { get; private set; }

    public bool IsFavorite { get; private set; }

    public bool PhraseIsEnabled { get; private set; }

    private void Save_Click(object sender, RoutedEventArgs e)
    {
        var title = TitleBox.Text.Trim();
        var text = TextBox.Text;
        if (string.IsNullOrWhiteSpace(title))
        {
            MessageBox.Show("Enter a phrase title.", "CommonCopy", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }

        if (string.IsNullOrEmpty(text))
        {
            MessageBox.Show("Enter phrase text.", "CommonCopy", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }

        if ((CategoryBox.SelectedItem as CategoryListItem)?.Id is not { } categoryId)
        {
            MessageBox.Show("Select a category.", "CommonCopy", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }

        PhraseTitle = title;
        PhraseText = text;
        CategoryId = categoryId;
        IsFavorite = FavoriteBox.IsChecked == true;
        PhraseIsEnabled = EnabledBox.IsChecked == true;
        DialogResult = true;
    }
}
