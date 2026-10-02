using CommonCopy.Core.Models;

namespace CommonCopy.Core.Services;

public static class PhraseLibraryValidator
{
    public static IReadOnlyList<string> Validate(PhraseLibraryDocument? document)
    {
        var errors = new List<string>();

        if (document is null)
        {
            errors.Add("The phrase library is empty.");
            return errors;
        }

        if (document.SchemaVersion != 1)
        {
            errors.Add($"Unsupported schema version: {document.SchemaVersion}.");
        }

        document.Categories ??= [];
        document.Phrases ??= [];
        document.Settings ??= new AppSettings();

        var categoryIds = new HashSet<Guid>();
        foreach (var category in document.Categories)
        {
            if (category.Id == Guid.Empty)
            {
                errors.Add("A category has an empty identifier.");
            }
            else if (!categoryIds.Add(category.Id))
            {
                errors.Add($"Duplicate category identifier: {category.Id}.");
            }

            if (string.IsNullOrWhiteSpace(category.Name))
            {
                errors.Add($"Category {category.Id} has no name.");
            }

            if (category.ParentId == category.Id)
            {
                errors.Add($"Category '{category.Name}' cannot be its own parent.");
            }
        }

        foreach (var category in document.Categories)
        {
            if (category.ParentId is { } parentId && !categoryIds.Contains(parentId))
            {
                errors.Add($"Category '{category.Name}' references a missing parent.");
            }

            if (HasCategoryCycle(category, document.Categories))
            {
                errors.Add($"Category '{category.Name}' is part of a parent cycle.");
            }
        }

        var phraseIds = new HashSet<Guid>();
        foreach (var phrase in document.Phrases)
        {
            if (phrase.Id == Guid.Empty)
            {
                errors.Add("A phrase has an empty identifier.");
            }
            else if (!phraseIds.Add(phrase.Id))
            {
                errors.Add($"Duplicate phrase identifier: {phrase.Id}.");
            }

            if (!categoryIds.Contains(phrase.CategoryId))
            {
                errors.Add($"Phrase '{phrase.Title}' references a missing category.");
            }

            if (string.IsNullOrWhiteSpace(phrase.Title))
            {
                errors.Add($"Phrase {phrase.Id} has no title.");
            }

            if (string.IsNullOrEmpty(phrase.Text))
            {
                errors.Add($"Phrase '{phrase.Title}' has no text.");
            }
        }

        if (document.Settings.RecentPhraseLimit is < 1 or > 100)
        {
            errors.Add("Recent phrase limit must be between 1 and 100.");
        }

        if (document.Settings.Appearance is not ("Light" or "Dark"))
        {
            errors.Add("Appearance must be Light or Dark.");
        }

        if (document.Settings.PopupWidth is < 280 or > 1_200)
        {
            errors.Add("Popup width must be between 280 and 1200.");
        }

        if (document.Settings.PasteDelayMilliseconds is < 0 or > 5_000)
        {
            errors.Add("Paste delay must be between 0 and 5000 milliseconds.");
        }

        if (document.Settings.ClipboardRestoreDelayMilliseconds is < 100 or > 10_000)
        {
            errors.Add("Clipboard restore delay must be between 100 and 10000 milliseconds.");
        }

        return errors.Distinct(StringComparer.Ordinal).ToArray();
    }

    public static void EnsureValid(PhraseLibraryDocument document)
    {
        var errors = Validate(document);
        if (errors.Count > 0)
        {
            throw new InvalidDataException(string.Join(Environment.NewLine, errors));
        }
    }

    private static bool HasCategoryCycle(PhraseCategory start, IReadOnlyCollection<PhraseCategory> categories)
    {
        var byId = categories
            .GroupBy(category => category.Id)
            .ToDictionary(group => group.Key, group => group.First());
        var visited = new HashSet<Guid>();
        var current = start;

        while (current.ParentId is { } parentId && byId.TryGetValue(parentId, out var parent))
        {
            if (!visited.Add(parentId))
            {
                return true;
            }

            current = parent;
        }

        return false;
    }
}
