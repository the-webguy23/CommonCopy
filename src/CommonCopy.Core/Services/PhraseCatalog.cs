using CommonCopy.Core.Models;

namespace CommonCopy.Core.Services;

public sealed class PhraseCatalog(PhraseLibraryDocument document)
{
    public IReadOnlyList<CategoryListItem> GetCategoryList(bool includeAll = true)
    {
        var result = new List<CategoryListItem>();
        if (includeAll)
        {
            result.Add(new CategoryListItem(null, "All phrases", CategoryListKind.All));
            result.Add(new CategoryListItem(null, "Favourites", CategoryListKind.Favourites));
            result.Add(new CategoryListItem(null, "Commonly Used", CategoryListKind.CommonlyUsed));
        }

        AddChildren(result, null, 0);
        return result;
    }

    public IReadOnlyList<PhraseEntry> Search(Guid? categoryId, string? query, bool includeDescendants = true)
    {
        IEnumerable<PhraseEntry> phrases = document.Phrases;

        if (categoryId is { } selectedCategoryId)
        {
            var categoryIds = includeDescendants
                ? GetDescendantCategoryIds(selectedCategoryId)
                : new HashSet<Guid> { selectedCategoryId };
            phrases = phrases.Where(phrase => categoryIds.Contains(phrase.CategoryId));
        }

        if (!string.IsNullOrWhiteSpace(query))
        {
            var trimmedQuery = query.Trim();
            phrases = phrases.Where(phrase =>
                phrase.Title.Contains(trimmedQuery, StringComparison.OrdinalIgnoreCase) ||
                phrase.Text.Contains(trimmedQuery, StringComparison.OrdinalIgnoreCase));
        }

        return phrases
            .OrderBy(phrase => phrase.CategoryId)
            .ThenBy(phrase => phrase.SortOrder)
            .ThenBy(phrase => phrase.Title, StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    public IReadOnlyList<PhraseEntry> GetFavorites() => document.Phrases
        .Where(phrase => phrase.IsEnabled && phrase.IsFavorite)
        .OrderByDescending(phrase => phrase.LastUsedAt)
        .ThenBy(phrase => phrase.Title, StringComparer.OrdinalIgnoreCase)
        .ToArray();

    public IReadOnlyList<PhraseEntry> GetCommonlyUsed(int? limit = null) => document.Phrases
        .Where(phrase => phrase.IsEnabled && phrase.UseCount > 0)
        .OrderByDescending(phrase => phrase.UseCount)
        .ThenByDescending(phrase => phrase.LastUsedAt)
        .ThenBy(phrase => phrase.Title, StringComparer.OrdinalIgnoreCase)
        .Take(limit ?? document.Settings.RecentPhraseLimit)
        .ToArray();

    public IReadOnlyList<PhraseCategory> GetChildCategories(Guid? parentId) => document.Categories
        .Where(category => category.IsEnabled && category.ParentId == parentId)
        .OrderBy(category => category.SortOrder)
        .ThenBy(category => category.Name, StringComparer.OrdinalIgnoreCase)
        .ToArray();

    public IReadOnlyList<PhraseEntry> GetEnabledPhrases(Guid categoryId) => document.Phrases
        .Where(phrase => phrase.IsEnabled && phrase.CategoryId == categoryId)
        .OrderBy(phrase => phrase.SortOrder)
        .ThenBy(phrase => phrase.Title, StringComparer.OrdinalIgnoreCase)
        .ToArray();

    public HashSet<Guid> GetDescendantCategoryIds(Guid rootId)
    {
        var result = new HashSet<Guid> { rootId };
        var pending = new Queue<Guid>();
        pending.Enqueue(rootId);

        while (pending.TryDequeue(out var parentId))
        {
            foreach (var child in document.Categories.Where(category => category.ParentId == parentId))
            {
                if (result.Add(child.Id))
                {
                    pending.Enqueue(child.Id);
                }
            }
        }

        return result;
    }

    public void RecordUse(PhraseEntry phrase)
    {
        phrase.UseCount++;
        phrase.LastUsedAt = DateTimeOffset.UtcNow;
        phrase.UpdatedAt = phrase.LastUsedAt.Value;
    }

    public void NormalizeSortOrders(Guid categoryId)
    {
        var phrases = document.Phrases
            .Where(phrase => phrase.CategoryId == categoryId)
            .OrderBy(phrase => phrase.SortOrder)
            .ThenBy(phrase => phrase.Title, StringComparer.OrdinalIgnoreCase)
            .ToArray();

        for (var index = 0; index < phrases.Length; index++)
        {
            phrases[index].SortOrder = index;
        }
    }

    private void AddChildren(List<CategoryListItem> result, Guid? parentId, int depth)
    {
        foreach (var category in GetChildCategories(parentId))
        {
            var prefix = depth == 0 ? string.Empty : $"{new string(' ', depth * 2)}↳ ";
            result.Add(new CategoryListItem(category.Id, $"{prefix}{category.Name}"));
            AddChildren(result, category.Id, depth + 1);
        }
    }
}
