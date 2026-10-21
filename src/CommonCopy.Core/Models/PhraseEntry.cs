namespace CommonCopy.Core.Models;

public sealed class PhraseEntry
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid CategoryId { get; set; }

    public string Title { get; set; } = string.Empty;

    public string Text { get; set; } = string.Empty;

    public int SortOrder { get; set; }

    public bool IsFavorite { get; set; }

    public bool IsEnabled { get; set; } = true;

    public int UseCount { get; set; }

    public DateTimeOffset? LastUsedAt { get; set; }

    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;

    public PhraseEntry Duplicate()
    {
        var now = DateTimeOffset.UtcNow;

        return new PhraseEntry
        {
            Id = Guid.NewGuid(),
            CategoryId = CategoryId,
            Title = $"{Title} (copy)",
            Text = Text,
            SortOrder = SortOrder + 1,
            IsFavorite = false,
            IsEnabled = IsEnabled,
            CreatedAt = now,
            UpdatedAt = now,
        };
    }
}
