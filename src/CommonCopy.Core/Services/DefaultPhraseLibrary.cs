using CommonCopy.Core.Models;

namespace CommonCopy.Core.Services;

public static class DefaultPhraseLibrary
{
    public static PhraseLibraryDocument Create()
    {
        var promptsId = Guid.NewGuid();
        var codeId = Guid.NewGuid();
        var dayToDayId = Guid.NewGuid();

        return new PhraseLibraryDocument
        {
            Categories =
            [
                new PhraseCategory { Id = promptsId, Name = "Prompts", SortOrder = 0 },
                new PhraseCategory { Id = codeId, Name = "Code", SortOrder = 1 },
                new PhraseCategory { Id = dayToDayId, Name = "Day-to-Day", SortOrder = 2 },
            ],
            Phrases =
            [
                new PhraseEntry
                {
                    CategoryId = promptsId,
                    Title = "Draft a clear reply",
                    Text = "Draft a clear, friendly reply to the following message:",
                    SortOrder = 0,
                    IsFavorite = true,
                },
                new PhraseEntry
                {
                    CategoryId = codeId,
                    Title = "HTML document",
                    Text = "<!doctype html>\n<html lang=\"en\">\n<head>\n  <meta charset=\"utf-8\">\n  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n  <title>Document</title>\n</head>\n<body>\n</body>\n</html>",
                    SortOrder = 0,
                },
                new PhraseEntry
                {
                    CategoryId = dayToDayId,
                    Title = "Signature",
                    Text = "Best regards,\nYour Name",
                    SortOrder = 0,
                },
            ],
        };
    }
}
