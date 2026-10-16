using CommonCopy.Core.Services;
using CommonCopy.DesktopBridge;

namespace CommonCopy.Core.Tests;

public sealed class DesktopBridgeTests
{
    [Fact]
    public async Task NestedPrompts_RoundTripsThroughCoreAndWindowsCompatibleExport()
    {
        using var directory = new TemporaryDirectory();
        var bridge = new BridgeService(directory.Path);
        var state = await bridge.ExecuteAsync(new("snapshot"));
        var prompts = Assert.Single(state.Document.Categories, item => item.Name == "Prompts");
        state = await bridge.ExecuteAsync(new("saveCategory", ParentId: prompts.Id, Name: "GPT"));
        var gpt = Assert.Single(state.Document.Categories, item => item.Name == "GPT");
        state = await bridge.ExecuteAsync(new("saveCategory", ParentId: gpt.Id, Name: "My project"));
        var project = Assert.Single(state.Document.Categories, item => item.Name == "My project");
        state = await bridge.ExecuteAsync(new("savePhrase", CategoryId: project.Id,
            Title: "Review", Text: "Review this code.\nKeep it clear. 🧠", IsFavorite: true));
        var phrase = Assert.Single(state.Document.Phrases, item => item.Title == "Review");
        Assert.Contains(phrase.Id, state.CategoryPhrases[prompts.Id]);
        Assert.Contains(phrase.Id, state.Favourites);
        state = await bridge.ExecuteAsync(new("recordUse", Id: phrase.Id));
        Assert.Equal(phrase.Id, Assert.Single(state.CommonlyUsed));
        var export = System.IO.Path.Combine(directory.Path, "portable.json");
        await bridge.ExecuteAsync(new("export", Path: export));
        using var other = new TemporaryDirectory();
        var windowsRepository = new JsonPhraseRepository(other.Path);
        var imported = await windowsRepository.ImportAsync(export);
        Assert.Equal(project.Id, imported.Phrases.Single(item => item.Id == phrase.Id).CategoryId);
        Assert.Equal(1, imported.Phrases.Single(item => item.Id == phrase.Id).UseCount);
        Assert.Equal("Review this code.\nKeep it clear. 🧠", imported.Phrases.Single(item => item.Id == phrase.Id).Text);
    }

    [Fact]
    public async Task InvalidCycleAndPhrase_DoNotModifySavedLibrary()
    {
        using var directory = new TemporaryDirectory();
        var bridge = new BridgeService(directory.Path);
        var state = await bridge.ExecuteAsync(new("snapshot"));
        var prompts = state.Document.Categories[0];
        await bridge.ExecuteAsync(new("saveCategory", ParentId: prompts.Id, Name: "GPT"));
        var saved = await File.ReadAllTextAsync(System.IO.Path.Combine(directory.Path, "phrases.json"));
        state = await bridge.ExecuteAsync(new("snapshot"));
        var child = state.Document.Categories.Single(item => item.Name == "GPT");
        await Assert.ThrowsAsync<InvalidDataException>(() => bridge.ExecuteAsync(
            new("saveCategory", Id: prompts.Id, ParentId: child.Id, Name: prompts.Name)));
        await Assert.ThrowsAsync<InvalidDataException>(() => bridge.ExecuteAsync(
            new("savePhrase", CategoryId: Guid.NewGuid(), Title: "Invalid", Text: "Test")));
        Assert.Equal(saved, await File.ReadAllTextAsync(System.IO.Path.Combine(directory.Path, "phrases.json")));
    }

    [Fact]
    public async Task AppearanceAndPhraseEdits_PreserveWindowsSettingsAndBackup()
    {
        using var directory = new TemporaryDirectory();
        var repository = new JsonPhraseRepository(directory.Path);
        var original = await repository.LoadAsync();
        original.Settings.StartWithWindows = true;
        original.Settings.KeyboardShortcut = "Alt+Shift+Space";
        await repository.SaveAsync(original);
        var bridge = new BridgeService(directory.Path);
        await bridge.ExecuteAsync(new("appearance", Appearance: "Dark"));
        var state = await bridge.ExecuteAsync(new("snapshot"));
        Assert.True(state.Document.Settings.StartWithWindows);
        Assert.Equal("Alt+Shift+Space", state.Document.Settings.KeyboardShortcut);
        Assert.Equal("Dark", state.Document.Settings.Appearance);
        Assert.True(File.Exists(repository.BackupPath));
        await Assert.ThrowsAsync<InvalidDataException>(() => bridge.ExecuteAsync(new("appearance", Appearance: "Other")));
        Assert.Equal("Dark", (await repository.LoadAsync()).Settings.Appearance);
    }

    [Fact]
    public async Task DeleteParent_RemovesOnlyItsSubtreeAndPhrases()
    {
        using var directory = new TemporaryDirectory();
        var bridge = new BridgeService(directory.Path);
        var state = await bridge.ExecuteAsync(new("snapshot"));
        var prompts = state.Document.Categories.Single(item => item.Name == "Prompts");
        await bridge.ExecuteAsync(new("saveCategory", ParentId: prompts.Id, Name: "Image based"));
        state = await bridge.ExecuteAsync(new("deleteCategory", Id: prompts.Id));
        Assert.DoesNotContain(state.Document.Categories, item => item.Name is "Prompts" or "Image based");
        Assert.Equal(2, state.Document.Phrases.Count);
        Assert.Contains(state.Document.Categories, item => item.Name == "Code");
    }

    [Fact]
    public async Task DisabledUseAndInvalidImport_PreserveExistingData()
    {
        using var directory = new TemporaryDirectory();
        var bridge = new BridgeService(directory.Path);
        var state = await bridge.ExecuteAsync(new("snapshot"));
        var phrase = state.Document.Phrases[0];
        await bridge.ExecuteAsync(new("savePhrase", Id: phrase.Id, CategoryId: phrase.CategoryId,
            Title: phrase.Title, Text: phrase.Text, IsEnabled: false));
        var saved = await File.ReadAllTextAsync(System.IO.Path.Combine(directory.Path, "phrases.json"));
        await Assert.ThrowsAsync<InvalidDataException>(() => bridge.ExecuteAsync(new("recordUse", Id: phrase.Id)));
        var badFile = System.IO.Path.Combine(directory.Path, "invalid.json");
        await File.WriteAllTextAsync(badFile, "{\"SchemaVersion\": 99}");
        await Assert.ThrowsAsync<InvalidDataException>(() => bridge.ExecuteAsync(new("import", Path: badFile)));
        Assert.Equal(saved, await File.ReadAllTextAsync(System.IO.Path.Combine(directory.Path, "phrases.json")));
    }

    [Fact]
    public async Task Export_CannotOverwriteInternalFiles()
    {
        using var directory = new TemporaryDirectory();
        var bridge = new BridgeService(directory.Path);
        await bridge.ExecuteAsync(new("snapshot"));
        foreach (var name in new[] { "phrases.json", "phrases.backup.json", ".desktop.lock" })
            await Assert.ThrowsAsync<InvalidDataException>(() => bridge.ExecuteAsync(
                new("export", Path: System.IO.Path.Combine(directory.Path, name))));
    }
}
