using System.Text.Json;
using CommonCopy.Core.Models;
using CommonCopy.Core.Services;

namespace CommonCopy.Core.Tests;

public sealed class JsonPhraseRepositoryTests
{
    [Fact]
    public async Task LoadAsync_MigratesLegacyPhrasesAndSettingsWithoutChangingOriginal()
    {
        using var directory = new TemporaryDirectory();
        var oldPath = Path.Combine(directory.Path, "PhraseMenu");
        var newPath = Path.Combine(directory.Path, "CommonCopy");
        var legacy = new JsonPhraseRepository(oldPath);
        var original = await legacy.LoadAsync();
        original.Settings.StartWithWindows = true;
        original.Phrases[0].UseCount = 17;
        await legacy.SaveAsync(original);
        var oldBytes = await File.ReadAllBytesAsync(legacy.DataPath);

        var migrated = await new JsonPhraseRepository(newPath, oldPath).LoadAsync();

        Assert.True(migrated.Settings.StartWithWindows);
        Assert.Equal(17, migrated.Phrases[0].UseCount);
        Assert.Equal(oldBytes, await File.ReadAllBytesAsync(Path.Combine(newPath, "phrases.json")));
        Assert.Equal(oldBytes, await File.ReadAllBytesAsync(legacy.DataPath));
        Assert.True(File.Exists(Path.Combine(newPath, "phrases.backup.json")));
    }

    [Fact]
    public async Task LoadAsync_DoesNotOverwriteExistingCommonCopyData()
    {
        using var directory = new TemporaryDirectory();
        var oldPath = Path.Combine(directory.Path, "PhraseMenu");
        var newPath = Path.Combine(directory.Path, "CommonCopy");
        var legacy = new JsonPhraseRepository(oldPath);
        var current = new JsonPhraseRepository(newPath);
        var old = await legacy.LoadAsync();
        var newDocument = await current.LoadAsync();
        newDocument.Phrases[0].Title = "New data wins";
        await current.SaveAsync(newDocument);

        var loaded = await new JsonPhraseRepository(newPath, oldPath).LoadAsync();

        Assert.Equal("New data wins", loaded.Phrases[0].Title);
        Assert.NotEqual(old.Phrases[0].Title, loaded.Phrases[0].Title);
    }

    [Fact]
    public async Task LoadAsync_InvalidLegacyDataDoesNotCreateDefaultLibrary()
    {
        using var directory = new TemporaryDirectory();
        var oldPath = Path.Combine(directory.Path, "PhraseMenu");
        var newPath = Path.Combine(directory.Path, "CommonCopy");
        Directory.CreateDirectory(oldPath);
        await File.WriteAllTextAsync(Path.Combine(oldPath, "phrases.json"), "{invalid");

        await Assert.ThrowsAnyAsync<Exception>(() => new JsonPhraseRepository(newPath, oldPath).LoadAsync());

        Assert.False(File.Exists(Path.Combine(newPath, "phrases.json")));
    }

    [Fact]
    public async Task LoadAsync_CreatesDefaultsWhenDataDoesNotExist()
    {
        using var directory = new TemporaryDirectory();
        var repository = new JsonPhraseRepository(directory.Path);

        var document = await repository.LoadAsync();

        Assert.NotEmpty(document.Categories);
        Assert.NotEmpty(document.Phrases);
        Assert.True(File.Exists(repository.DataPath));
        Assert.Empty(PhraseLibraryValidator.Validate(document));
    }

    [Fact]
    public async Task SaveAsync_RoundTripsUnicodeAndMultilineText()
    {
        using var directory = new TemporaryDirectory();
        var repository = new JsonPhraseRepository(directory.Path);
        var document = DefaultPhraseLibrary.Create();
        var categoryId = document.Categories[0].Id;
        document.Phrases.Add(new PhraseEntry
        {
            CategoryId = categoryId,
            Title = "Unicode",
            Text = "Hello 👋\nΚαλημέρα\nこんにちは",
            SortOrder = 50,
        });

        await repository.SaveAsync(document);
        var reloaded = await repository.LoadAsync();

        var phrase = Assert.Single(reloaded.Phrases, item => item.Title == "Unicode");
        Assert.Equal("Hello 👋\nΚαλημέρα\nこんにちは", phrase.Text);
    }

    [Fact]
    public async Task SaveAsync_CreatesBackupOfPreviousValidData()
    {
        using var directory = new TemporaryDirectory();
        var repository = new JsonPhraseRepository(directory.Path);
        var original = await repository.LoadAsync();
        var originalCount = original.Phrases.Count;
        original.Phrases.Add(new PhraseEntry
        {
            CategoryId = original.Categories[0].Id,
            Title = "New phrase",
            Text = "New text",
        });

        await repository.SaveAsync(original);

        Assert.True(File.Exists(repository.BackupPath));
        var backupJson = await File.ReadAllTextAsync(repository.BackupPath);
        var backup = JsonSerializer.Deserialize<PhraseLibraryDocument>(backupJson);
        Assert.NotNull(backup);
        Assert.Equal(originalCount, backup.Phrases.Count);
    }

    [Fact]
    public async Task ImportAsync_RejectsMissingCategoryWithoutChangingCurrentData()
    {
        using var directory = new TemporaryDirectory();
        var repository = new JsonPhraseRepository(directory.Path);
        var current = await repository.LoadAsync();
        var invalidPath = System.IO.Path.Combine(directory.Path, "invalid.json");
        var invalid = DefaultPhraseLibrary.Create();
        invalid.Phrases[0].CategoryId = Guid.NewGuid();
        await File.WriteAllTextAsync(invalidPath, JsonSerializer.Serialize(invalid));

        await Assert.ThrowsAsync<InvalidDataException>(() => repository.ImportAsync(invalidPath));

        var reloaded = await repository.LoadAsync();
        Assert.Equal(current.Phrases.Count, reloaded.Phrases.Count);
    }

    [Fact]
    public async Task LoadAsync_PreservesCorruptFileAndRecoversBackup()
    {
        using var directory = new TemporaryDirectory();
        var repository = new JsonPhraseRepository(directory.Path);
        var document = await repository.LoadAsync();
        document.Phrases.Add(new PhraseEntry
        {
            CategoryId = document.Categories[0].Id,
            Title = "Creates backup",
            Text = "Second version",
        });
        await repository.SaveAsync(document);
        await File.WriteAllTextAsync(repository.DataPath, "{ definitely not valid json");

        var recovered = await repository.LoadAsync();

        Assert.DoesNotContain(recovered.Phrases, phrase => phrase.Title == "Creates backup");
        Assert.NotEmpty(Directory.GetFiles(directory.Path, "phrases.corrupt-*.json"));
    }
}
