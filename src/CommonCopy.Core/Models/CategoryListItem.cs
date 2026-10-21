namespace CommonCopy.Core.Models;

public enum CategoryListKind { All, Favourites, CommonlyUsed, Category }

public sealed record CategoryListItem(Guid? Id, string DisplayName, CategoryListKind Kind = CategoryListKind.Category)
{
    public override string ToString() => DisplayName;
}
