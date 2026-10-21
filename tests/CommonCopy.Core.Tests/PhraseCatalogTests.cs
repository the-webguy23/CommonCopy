using CommonCopy.Core.Models;
using CommonCopy.Core.Services;

namespace CommonCopy.Core.Tests;

public sealed class PhraseCatalogTests
{
    [Fact]
    public void Search_IncludesNestedCategoryPhrases()
    {
        var document = DefaultPhraseLibrary.Create();
        var prompts = Assert.Single(document.Categories, category => category.Name == "Prompts");
        var catalog = new PhraseCatalog(document);

        var phrases = catalog.Search(prompts.Id, null);

        Assert.Contains(phrases, phrase => phrase.Title == "Draft a clear reply");
    }

    [Fact]
    public void Search_MatchesTitleAndBodyCaseInsensitively()
    {
        var document = DefaultPhraseLibrary.Create();
        var catalog = new PhraseCatalog(document);

        var byTitle = catalog.Search(null, "HTML DOCUMENT");
        var byBody = catalog.Search(null, "FRIENDLY REPLY");

        Assert.Single(byTitle);
        Assert.Single(byBody);
    }

    [Fact]
    public void RecordUse_AddsPhraseToCommonlyUsed()
    {
        var document = DefaultPhraseLibrary.Create();
        var catalog = new PhraseCatalog(document);
        var phrase = document.Phrases[0];

        catalog.RecordUse(phrase);

        Assert.Equal(1, phrase.UseCount);
        Assert.NotNull(phrase.LastUsedAt);
        Assert.Same(phrase, Assert.Single(catalog.GetCommonlyUsed()));
    }

    [Fact]
    public void CommonlyUsed_SortsByCountThenRecentUse()
    {
        var document = DefaultPhraseLibrary.Create();
        var catalog = new PhraseCatalog(document);
        var first = document.Phrases[0];
        var second = document.Phrases[1];
        var third = document.Phrases[2];
        first.UseCount = 3;
        first.LastUsedAt = DateTimeOffset.UtcNow.AddDays(-2);
        second.UseCount = 3;
        second.LastUsedAt = DateTimeOffset.UtcNow.AddDays(-1);
        third.UseCount = 4;
        third.LastUsedAt = DateTimeOffset.UtcNow.AddDays(-10);

        Assert.Equal(new[] { third, second, first }, catalog.GetCommonlyUsed());
    }

    [Fact]
    public void Validator_RejectsCategoryCycles()
    {
        var first = new PhraseCategory { Name = "First" };
        var second = new PhraseCategory { Name = "Second", ParentId = first.Id };
        first.ParentId = second.Id;
        var document = new PhraseLibraryDocument
        {
            Categories = [first, second],
        };

        var errors = PhraseLibraryValidator.Validate(document);

        Assert.Contains(errors, error => error.Contains("cycle", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void PhraseTitleGenerator_NormalizesWhitespace()
    {
        var title = PhraseTitleGenerator.Create("  First line\r\nsecond\tline  ");

        Assert.Equal("First line second line", title);
    }

    [Fact]
    public void PhraseTitleGenerator_TruncatesLongSelections()
    {
        var title = PhraseTitleGenerator.Create(new string('a', 80));

        Assert.Equal(60, title.Length);
        Assert.EndsWith("…", title);
    }

    [Fact]
    public void PhraseTitleGenerator_UsesFallbackForWhitespace()
    {
        Assert.Equal("Captured phrase", PhraseTitleGenerator.Create(" \r\n\t "));
    }
}
