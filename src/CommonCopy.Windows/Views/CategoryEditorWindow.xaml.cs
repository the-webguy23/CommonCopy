using System.Windows;
using CommonCopy.Core.Models;

namespace CommonCopy.Windows.Views;

public partial class CategoryEditorWindow : Window
{
    public CategoryEditorWindow(
        IReadOnlyList<CategoryListItem> parentOptions,
        PhraseCategory? category)
    {
        InitializeComponent();
        ParentBox.ItemsSource = parentOptions;
        ParentBox.SelectedItem = parentOptions.FirstOrDefault(option => option.Id == category?.ParentId) ?? parentOptions.First();
        NameBox.Text = category?.Name ?? string.Empty;
        Loaded += (_, _) =>
        {
            NameBox.Focus();
            NameBox.SelectAll();
        };
    }

    public string CategoryName { get; private set; } = string.Empty;

    public Guid? ParentId { get; private set; }

    private void Save_Click(object sender, RoutedEventArgs e)
    {
        var name = NameBox.Text.Trim();
        if (string.IsNullOrWhiteSpace(name))
        {
            MessageBox.Show("Enter a category name.", "CommonCopy", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }

        CategoryName = name;
        ParentId = (ParentBox.SelectedItem as CategoryListItem)?.Id;
        DialogResult = true;
    }
}
