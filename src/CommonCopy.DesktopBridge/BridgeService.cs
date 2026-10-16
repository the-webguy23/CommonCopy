using CommonCopy.Core.Models;
using CommonCopy.Core.Services;

namespace CommonCopy.DesktopBridge;

public sealed record BridgeRequest(
    string Operation,
    Guid? Id = null,
    Guid? CategoryId = null,
    Guid? ParentId = null,
    string? Name = null,
    string? Title = null,
    string? Text = null,
    bool IsFavorite = false,
    bool IsEnabled = true,
    string? Appearance = null,
    string? Path = null);

public sealed record BridgeState(
    PhraseLibraryDocument Document,
    IReadOnlyList<CategoryListItem> CategoryList,
    Guid[] Favourites,
    Guid[] CommonlyUsed,
    Dictionary<Guid, Guid[]> CategoryPhrases);

public sealed class BridgeService(string dataDirectory)
{
    public async Task<BridgeState> ExecuteAsync(BridgeRequest request)
    {
        var repository = new JsonPhraseRepository(dataDirectory);
        var document = await repository.LoadAsync();
        var catalog = new PhraseCatalog(document);
        var changed = true;

        switch (request.Operation)
        {
            case "snapshot":
                changed = false;
                break;
            case "saveCategory":
            {
                var category = request.Id is { } id
                    ? document.Categories.Single(item => item.Id == id)
                    : new PhraseCategory { SortOrder = document.Categories.Count(item => item.ParentId == request.ParentId) };
                category.Name = request.Name?.Trim() ?? string.Empty;
                category.ParentId = request.ParentId;
                category.UpdatedAt = DateTimeOffset.UtcNow;
                if (request.Id is null) document.Categories.Add(category);
                break;
            }
            case "deleteCategory":
            {
                var id = request.Id ?? throw new InvalidDataException();
                _ = document.Categories.Single(item => item.Id == id);
                var ids = catalog.GetDescendantCategoryIds(id);
                document.Phrases.RemoveAll(item => ids.Contains(item.CategoryId));
                document.Categories.RemoveAll(item => ids.Contains(item.Id));
                break;
            }
            case "savePhrase":
            {
                var categoryId = request.CategoryId ?? throw new InvalidDataException();
                var phrase = request.Id is { } id
                    ? document.Phrases.Single(item => item.Id == id)
                    : new PhraseEntry { SortOrder = document.Phrases.Count(item => item.CategoryId == categoryId) };
                phrase.CategoryId = categoryId;
                phrase.Title = request.Title?.Trim() ?? string.Empty;
                phrase.Text = request.Text ?? string.Empty;
                phrase.IsFavorite = request.IsFavorite;
                phrase.IsEnabled = request.IsEnabled;
                phrase.UpdatedAt = DateTimeOffset.UtcNow;
                if (request.Id is null) document.Phrases.Add(phrase);
                break;
            }
            case "deletePhrase":
                document.Phrases.Remove(document.Phrases.Single(item => item.Id == request.Id));
                break;
            case "duplicatePhrase":
            {
                var duplicate = document.Phrases.Single(item => item.Id == request.Id).Duplicate();
                document.Phrases.Add(duplicate);
                catalog.NormalizeSortOrders(duplicate.CategoryId);
                break;
            }
            case "recordUse":
            {
                var phrase = document.Phrases.Single(item => item.Id == request.Id);
                if (!phrase.IsEnabled) throw new InvalidDataException();
                catalog.RecordUse(phrase);
                break;
            }
            case "appearance":
                document.Settings.Appearance = request.Appearance ?? string.Empty;
                break;
            case "import":
                document = await repository.ImportAsync(request.Path ?? string.Empty);
                catalog = new PhraseCatalog(document);
                changed = false;
                break;
            case "export":
            {
                var path = System.IO.Path.GetFullPath(request.Path ?? string.Empty);
                // Export must not bypass the repository's backup or lock files.
                var internalPaths = new[] { repository.DataPath, repository.BackupPath,
                    System.IO.Path.Combine(dataDirectory, ".desktop.lock") };
                if (internalPaths.Any(item => string.Equals(System.IO.Path.GetFullPath(item), path,
                    StringComparison.OrdinalIgnoreCase))) throw new InvalidDataException();
                await repository.ExportAsync(document, path);
                changed = false;
                break;
            }
            default:
                throw new InvalidDataException();
        }

        if (changed) await repository.SaveAsync(document);
        return new BridgeState(document, catalog.GetCategoryList(includeAll: false),
            catalog.GetFavorites().Select(item => item.Id).ToArray(),
            catalog.GetCommonlyUsed().Select(item => item.Id).ToArray(),
            document.Categories.ToDictionary(item => item.Id,
                item => catalog.Search(item.Id, null).Select(phrase => phrase.Id).ToArray()));
    }
}
