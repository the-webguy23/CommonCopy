namespace CommonCopy.Core.Services;

public static class PhraseTitleGenerator
{
    public const int DefaultMaximumLength = 60;

    public static string Create(string? text, int maximumLength = DefaultMaximumLength)
    {
        if (maximumLength < 2)
        {
            throw new ArgumentOutOfRangeException(nameof(maximumLength), "The maximum title length must be at least 2.");
        }

        var normalized = string.Join(
            " ",
            (text ?? string.Empty).Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries));

        if (normalized.Length == 0)
        {
            return "Captured phrase";
        }

        return normalized.Length <= maximumLength
            ? normalized
            : $"{normalized[..(maximumLength - 1)].TrimEnd()}…";
    }
}
