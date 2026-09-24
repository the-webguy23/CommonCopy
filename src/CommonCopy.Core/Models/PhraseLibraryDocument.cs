namespace CommonCopy.Core.Models;

public sealed class PhraseLibraryDocument
{
    public int SchemaVersion { get; set; } = 1;

    public List<PhraseCategory> Categories { get; set; } = [];

    public List<PhraseEntry> Phrases { get; set; } = [];

    public AppSettings Settings { get; set; } = new();
}
