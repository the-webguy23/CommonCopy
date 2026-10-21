using System.Windows;

namespace CommonCopy.Windows;

internal static class AppearanceTheme
{
    private static ResourceDictionary? activePalette;

    public static void Apply(string appearance)
    {
        var resources = Application.Current.Resources.MergedDictionaries;
        var palette = new ResourceDictionary
        {
            Source = new Uri(
                $"pack://application:,,,/Themes/{(appearance == "Dark" ? "Dark" : "Light")}.xaml",
                UriKind.Absolute),
        };

        resources.Remove(activePalette ?? resources[0]);

        // Keep the palette before the common control styles; all theme-dependent
        // properties use DynamicResource so open windows update immediately.
        resources.Insert(0, palette);
        activePalette = palette;
    }
}
