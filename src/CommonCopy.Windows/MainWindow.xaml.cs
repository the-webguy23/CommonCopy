using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;
using Microsoft.Win32;
using CommonCopy.Core.Models;
using CommonCopy.Core.Services;
using CommonCopy.Windows.Views;

namespace CommonCopy.Windows;

public sealed class DocumentReplacedEventArgs(PhraseLibraryDocument document) : EventArgs
{
    public PhraseLibraryDocument Document { get; } = document;
}

public partial class MainWindow : Window
{
    private readonly JsonPhraseRepository repository;
    private readonly Action showPopup;
    private readonly Action settingsChanged;
    private readonly Action exit;
    private readonly ObservableCollection<PhraseEntry> visiblePhrases = [];
    private PhraseLibraryDocument document;
    private bool ready;
    private bool refreshing;

    public MainWindow(
        JsonPhraseRepository repository,
        PhraseLibraryDocument document,
        Action showPopup,
        Action settingsChanged,
        Action exit)
    {
        InitializeComponent();
        this.repository = repository;
        this.document = document;
        this.showPopup = showPopup;
        this.settingsChanged = settingsChanged;
        this.exit = exit;
        PhraseGrid.ItemsSource = visiblePhrases;
        ready = true;
        RefreshView();
    }

    public event EventHandler<DocumentReplacedEventArgs>? DocumentReplaced;

    public async Task AddCapturedPhraseAsync(string text)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            throw new InvalidOperationException("The highlighted text was empty.");
        }

        PhraseCategory? temporaryCategory = null;
        if (new PhraseCatalog(document).GetCategoryList(includeAll: false).Count == 0)
        {
            temporaryCategory = new PhraseCategory
            {
                Name = "Captured",
                SortOrder = document.Categories.Count(category => category.ParentId is null),
            };
            document.Categories.Add(temporaryCategory);
        }

        var managerWasVisible = IsVisible;
        Show();
        if (WindowState == WindowState.Minimized)
        {
            WindowState = WindowState.Normal;
        }

        Activate();
        RefreshView();

        var categoryOptions = GetPhraseCategoryOptions();
        var currentCategoryId = (CategoryList.SelectedItem as CategoryListItem)?.Id;
        var selectedCategoryId = currentCategoryId is { } categoryId &&
                                 categoryOptions.Any(category => category.Id == categoryId)
            ? categoryId
            : categoryOptions[0].Id!.Value;
        var draft = new PhraseEntry
        {
            Title = PhraseTitleGenerator.Create(text),
            Text = text,
            CategoryId = selectedCategoryId,
        };
        var dialog = new PhraseEditorWindow(
            categoryOptions,
            draft,
            selectedCategoryId,
            "Save highlighted text")
        {
            Owner = this,
        };

        if (dialog.ShowDialog() != true)
        {
            if (temporaryCategory is not null)
            {
                document.Categories.Remove(temporaryCategory);
                RefreshView();
            }

            StatusText.Text = "Highlighted text was not saved.";
            if (!managerWasVisible)
            {
                Hide();
            }

            return;
        }

        var sortOrder = document.Phrases.Count(phrase => phrase.CategoryId == dialog.CategoryId);
        var phrase = new PhraseEntry
        {
            Title = dialog.PhraseTitle,
            Text = dialog.PhraseText,
            CategoryId = dialog.CategoryId,
            IsFavorite = dialog.IsFavorite,
            IsEnabled = dialog.PhraseIsEnabled,
            SortOrder = sortOrder,
        };
        document.Phrases.Add(phrase);
        await SaveAndRefreshAsync("Highlighted text saved.", phrase.Id);
        if (!managerWasVisible)
        {
            Hide();
        }
    }

    public void RefreshView()
    {
        var selectedCategory = CategoryList.SelectedItem as CategoryListItem;
        var selectedPhraseId = (PhraseGrid.SelectedItem as PhraseEntry)?.Id;
        refreshing = true;

        try
        {
            var catalog = new PhraseCatalog(document);
            var categories = catalog.GetCategoryList();
            CategoryList.ItemsSource = categories;
            CategoryList.SelectedItem = selectedCategory is null
                ? categories.FirstOrDefault()
                : categories.FirstOrDefault(item => item.Id == selectedCategory.Id && item.Kind == selectedCategory.Kind)
                    ?? categories.FirstOrDefault();

            visiblePhrases.Clear();
            foreach (var phrase in GetVisiblePhrases(catalog))
            {
                visiblePhrases.Add(phrase);
            }

            PhraseGrid.SelectedItem = visiblePhrases.FirstOrDefault(phrase => phrase.Id == selectedPhraseId);
            PhraseCountText.Text = $"{visiblePhrases.Count} shown · {document.Phrases.Count} total";
            StatusText.Text = $"Data: {repository.DataPath}";
        }
        finally
        {
            refreshing = false;
        }
    }

    private async void AddCategory_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new CategoryEditorWindow(GetParentOptions(), null) { Owner = this };
        if (dialog.ShowDialog() != true)
        {
            return;
        }

        var siblings = document.Categories.Where(category => category.ParentId == dialog.ParentId).ToArray();
        document.Categories.Add(new PhraseCategory
        {
            Name = dialog.CategoryName,
            ParentId = dialog.ParentId,
            SortOrder = siblings.Length,
        });
        await SaveAndRefreshAsync("Category added.");
    }

    private async void EditCategory_Click(object sender, RoutedEventArgs e)
    {
        if (!TryGetSelectedCategory(out var category))
        {
            return;
        }

        var excluded = new PhraseCatalog(document).GetDescendantCategoryIds(category.Id);
        var dialog = new CategoryEditorWindow(GetParentOptions(excluded), category) { Owner = this };
        if (dialog.ShowDialog() != true)
        {
            return;
        }

        category.Name = dialog.CategoryName;
        category.ParentId = dialog.ParentId;
        category.UpdatedAt = DateTimeOffset.UtcNow;
        await SaveAndRefreshAsync("Category updated.");
    }

    private async void DeleteCategory_Click(object sender, RoutedEventArgs e)
    {
        if (!TryGetSelectedCategory(out var category))
        {
            return;
        }

        var categoryIds = new PhraseCatalog(document).GetDescendantCategoryIds(category.Id);
        var phraseCount = document.Phrases.Count(phrase => categoryIds.Contains(phrase.CategoryId));
        var result = MessageBox.Show(
            $"Delete '{category.Name}', its nested categories, and {phraseCount} phrase(s)?",
            "Delete category",
            MessageBoxButton.YesNo,
            MessageBoxImage.Warning);
        if (result != MessageBoxResult.Yes)
        {
            return;
        }

        document.Phrases.RemoveAll(phrase => categoryIds.Contains(phrase.CategoryId));
        document.Categories.RemoveAll(item => categoryIds.Contains(item.Id));
        await SaveAndRefreshAsync("Category deleted.");
    }

    private async void AddPhrase_Click(object sender, RoutedEventArgs e)
    {
        if (document.Categories.Count == 0)
        {
            MessageBox.Show("Create a category before adding a phrase.", "CommonCopy", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }

        var selectedCategoryId = (CategoryList.SelectedItem as CategoryListItem)?.Id ?? document.Categories[0].Id;
        var dialog = new PhraseEditorWindow(GetPhraseCategoryOptions(), null, selectedCategoryId) { Owner = this };
        if (dialog.ShowDialog() != true)
        {
            return;
        }

        var sortOrder = document.Phrases.Count(phrase => phrase.CategoryId == dialog.CategoryId);
        document.Phrases.Add(new PhraseEntry
        {
            Title = dialog.PhraseTitle,
            Text = dialog.PhraseText,
            CategoryId = dialog.CategoryId,
            IsFavorite = dialog.IsFavorite,
            IsEnabled = dialog.PhraseIsEnabled,
            SortOrder = sortOrder,
        });
        await SaveAndRefreshAsync("Phrase added.");
    }

    private async void EditPhrase_Click(object sender, RoutedEventArgs e)
    {
        if (PhraseGrid.SelectedItem is not PhraseEntry phrase)
        {
            return;
        }

        var dialog = new PhraseEditorWindow(GetPhraseCategoryOptions(), phrase, phrase.CategoryId) { Owner = this };
        if (dialog.ShowDialog() != true)
        {
            return;
        }

        phrase.Title = dialog.PhraseTitle;
        phrase.Text = dialog.PhraseText;
        phrase.CategoryId = dialog.CategoryId;
        phrase.IsFavorite = dialog.IsFavorite;
        phrase.IsEnabled = dialog.PhraseIsEnabled;
        phrase.UpdatedAt = DateTimeOffset.UtcNow;
        await SaveAndRefreshAsync("Phrase updated.", phrase.Id);
    }

    private async void DuplicatePhrase_Click(object sender, RoutedEventArgs e)
    {
        if (PhraseGrid.SelectedItem is not PhraseEntry phrase)
        {
            return;
        }

        var duplicate = phrase.Duplicate();
        document.Phrases.Add(duplicate);
        new PhraseCatalog(document).NormalizeSortOrders(duplicate.CategoryId);
        await SaveAndRefreshAsync("Phrase duplicated.", duplicate.Id);
    }

    private async void ToggleFavorite_Click(object sender, RoutedEventArgs e)
    {
        if (PhraseGrid.SelectedItem is not PhraseEntry phrase)
        {
            return;
        }

        phrase.IsFavorite = !phrase.IsFavorite;
        phrase.UpdatedAt = DateTimeOffset.UtcNow;
        await SaveAndRefreshAsync(phrase.IsFavorite ? "Added to favorites." : "Removed from favorites.", phrase.Id);
    }

    private async void DeletePhrase_Click(object sender, RoutedEventArgs e)
    {
        if (PhraseGrid.SelectedItem is not PhraseEntry phrase)
        {
            return;
        }

        var result = MessageBox.Show(
            $"Delete '{phrase.Title}'?",
            "Delete phrase",
            MessageBoxButton.YesNo,
            MessageBoxImage.Warning);
        if (result != MessageBoxResult.Yes)
        {
            return;
        }

        document.Phrases.Remove(phrase);
        new PhraseCatalog(document).NormalizeSortOrders(phrase.CategoryId);
        await SaveAndRefreshAsync("Phrase deleted.");
    }

    private async void MovePhraseUp_Click(object sender, RoutedEventArgs e) => await MoveSelectedPhraseAsync(-1);

    private async void MovePhraseDown_Click(object sender, RoutedEventArgs e) => await MoveSelectedPhraseAsync(1);

    private void PhraseGrid_MouseDoubleClick(object sender, System.Windows.Input.MouseButtonEventArgs e) =>
        EditPhrase_Click(sender, e);

    private void SearchBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        if (ready)
        {
            RefreshView();
        }
    }

    private void CategoryList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (!refreshing)
        {
            RefreshVisiblePhrasesOnly();
        }
    }

    private void ShowPopup_Click(object sender, RoutedEventArgs e)
    {
        Hide();
        showPopup();
    }

    private async void Settings_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new SettingsWindow(document.Settings) { Owner = this };
        if (dialog.ShowDialog() != true)
        {
            return;
        }

        dialog.ApplyTo(document.Settings);
        await repository.SaveAsync(document);
        settingsChanged();
        StatusText.Text = "Settings saved.";
    }

    private async void ImportLibrary_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new OpenFileDialog
        {
            Title = "Import CommonCopy library",
            Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*",
            CheckFileExists = true,
        };
        if (dialog.ShowDialog(this) != true)
        {
            return;
        }

        try
        {
            document = await repository.ImportAsync(dialog.FileName);
            DocumentReplaced?.Invoke(this, new DocumentReplacedEventArgs(document));
            RefreshView();
            StatusText.Text = "Library imported.";
        }
        catch (Exception exception)
        {
            ShowOperationError("The library could not be imported.", exception);
        }
    }

    private async void ExportLibrary_Click(object sender, RoutedEventArgs e)
    {
        var dialog = CreateSaveDialog("Export CommonCopy library", "CommonCopy-library.json");
        if (dialog.ShowDialog(this) != true)
        {
            return;
        }

        try
        {
            await repository.ExportAsync(document, dialog.FileName);
            StatusText.Text = "Library exported.";
        }
        catch (Exception exception)
        {
            ShowOperationError("The library could not be exported.", exception);
        }
    }

    private async void CreateBackup_Click(object sender, RoutedEventArgs e)
    {
        var dialog = CreateSaveDialog(
            "Create CommonCopy backup",
            $"CommonCopy-backup-{DateTimeOffset.Now:yyyy-MM-dd}.json");
        if (dialog.ShowDialog(this) != true)
        {
            return;
        }

        try
        {
            await repository.SaveAsync(document);
            await repository.CreateBackupAsync(dialog.FileName);
            StatusText.Text = "Backup created.";
        }
        catch (Exception exception)
        {
            ShowOperationError("The backup could not be created.", exception);
        }
    }

    private async void RestoreBackup_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new OpenFileDialog
        {
            Title = "Restore CommonCopy backup",
            Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*",
            CheckFileExists = true,
        };
        if (dialog.ShowDialog(this) != true)
        {
            return;
        }

        if (MessageBox.Show(
                "Replace the current phrase library with this backup?",
                "Restore backup",
                MessageBoxButton.YesNo,
                MessageBoxImage.Warning) != MessageBoxResult.Yes)
        {
            return;
        }

        try
        {
            document = await repository.RestoreBackupAsync(dialog.FileName);
            DocumentReplaced?.Invoke(this, new DocumentReplacedEventArgs(document));
            RefreshView();
            StatusText.Text = "Backup restored.";
        }
        catch (Exception exception)
        {
            ShowOperationError("The backup could not be restored.", exception);
        }
    }

    private void OpenDataFolder_Click(object sender, RoutedEventArgs e)
    {
        Directory.CreateDirectory(repository.DataDirectory);
        Process.Start(new ProcessStartInfo
        {
            FileName = repository.DataDirectory,
            UseShellExecute = true,
        });
    }

    private void Exit_Click(object sender, RoutedEventArgs e) => exit();

    private void About_Click(object sender, RoutedEventArgs e) => MessageBox.Show(
        "CommonCopy\nSave it once. Paste it forever.\n\nWindows available; macOS planned.\nLicensed under the MIT License.",
        "About CommonCopy",
        MessageBoxButton.OK,
        MessageBoxImage.Information);

    private async Task MoveSelectedPhraseAsync(int offset)
    {
        if (PhraseGrid.SelectedItem is not PhraseEntry phrase)
        {
            return;
        }

        var catalog = new PhraseCatalog(document);
        catalog.NormalizeSortOrders(phrase.CategoryId);
        var siblings = document.Phrases
            .Where(item => item.CategoryId == phrase.CategoryId)
            .OrderBy(item => item.SortOrder)
            .ToList();
        var currentIndex = siblings.IndexOf(phrase);
        var targetIndex = currentIndex + offset;
        if (currentIndex < 0 || targetIndex < 0 || targetIndex >= siblings.Count)
        {
            return;
        }

        (siblings[currentIndex].SortOrder, siblings[targetIndex].SortOrder) =
            (siblings[targetIndex].SortOrder, siblings[currentIndex].SortOrder);
        await SaveAndRefreshAsync("Phrase reordered.", phrase.Id);
    }

    private void RefreshVisiblePhrasesOnly(Guid? selectedPhraseId = null)
    {
        var catalog = new PhraseCatalog(document);
        var previousPhraseId = selectedPhraseId ?? (PhraseGrid.SelectedItem as PhraseEntry)?.Id;
        visiblePhrases.Clear();
        foreach (var phrase in GetVisiblePhrases(catalog))
        {
            visiblePhrases.Add(phrase);
        }

        PhraseGrid.SelectedItem = visiblePhrases.FirstOrDefault(phrase => phrase.Id == previousPhraseId);
        PhraseCountText.Text = $"{visiblePhrases.Count} shown · {document.Phrases.Count} total";
    }

    private async Task SaveAndRefreshAsync(string status, Guid? selectedPhraseId = null)
    {
        try
        {
            await repository.SaveAsync(document);
            RefreshView();
            if (selectedPhraseId is not null)
            {
                PhraseGrid.SelectedItem = visiblePhrases.FirstOrDefault(phrase => phrase.Id == selectedPhraseId);
            }

            StatusText.Text = status;
        }
        catch (Exception exception)
        {
            ShowOperationError("CommonCopy could not save the change.", exception);
        }
    }

    private bool TryGetSelectedCategory(out PhraseCategory category)
    {
        var categoryId = (CategoryList.SelectedItem as CategoryListItem)?.Id;
        category = document.Categories.FirstOrDefault(item => item.Id == categoryId)!;
        if (category is null)
        {
            MessageBox.Show("Select a specific category first.", "CommonCopy", MessageBoxButton.OK, MessageBoxImage.Information);
            return false;
        }

        return true;
    }

    private IEnumerable<PhraseEntry> GetVisiblePhrases(PhraseCatalog catalog)
    {
        var selected = CategoryList.SelectedItem as CategoryListItem;
        var phrases = selected?.Kind switch
        {
            CategoryListKind.Favourites => catalog.GetFavorites(),
            CategoryListKind.CommonlyUsed => catalog.GetCommonlyUsed(),
            _ => catalog.Search(selected?.Id, null),
        };
        var query = SearchBox.Text?.Trim();
        return string.IsNullOrWhiteSpace(query) ? phrases : phrases.Where(phrase =>
            phrase.Title.Contains(query, StringComparison.OrdinalIgnoreCase) ||
            phrase.Text.Contains(query, StringComparison.OrdinalIgnoreCase));
    }

    private IReadOnlyList<CategoryListItem> GetParentOptions(ISet<Guid>? excluded = null)
    {
        var options = new List<CategoryListItem> { new(null, "(Top level)") };
        options.AddRange(new PhraseCatalog(document)
            .GetCategoryList(includeAll: false)
            .Where(item => item.Id is null || excluded is null || !excluded.Contains(item.Id.Value)));
        return options;
    }

    private IReadOnlyList<CategoryListItem> GetPhraseCategoryOptions() =>
        new PhraseCatalog(document).GetCategoryList(includeAll: false);

    private static SaveFileDialog CreateSaveDialog(string title, string fileName) => new()
    {
        Title = title,
        FileName = fileName,
        Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*",
        AddExtension = true,
        DefaultExt = ".json",
        OverwritePrompt = true,
    };

    private void ShowOperationError(string message, Exception exception) => MessageBox.Show(
        $"{message}\n\n{exception.Message}",
        "CommonCopy",
        MessageBoxButton.OK,
        MessageBoxImage.Error);
}
