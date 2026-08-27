namespace QuotaGrove.Core;

public enum QuotaTheme
{
    Forest,
    Autumn,
    Apocalypse,
    Wasteland
}

public sealed record QuotaThemeStyle(string AccentHex, string BorderHex, string BackgroundAsset);

public static class QuotaThemes
{
    public static QuotaTheme Select(double remainingPercent) => remainingPercent switch
    {
        >= 50 and <= 100 => QuotaTheme.Forest,
        >= 20 and < 50 => QuotaTheme.Autumn,
        >= 3 and < 20 => QuotaTheme.Apocalypse,
        _ => QuotaTheme.Wasteland
    };

    public static QuotaThemeStyle Style(QuotaTheme theme) => theme switch
    {
        QuotaTheme.Forest => new("#78E0AB", "#6FCF9B", "forest.png"),
        QuotaTheme.Autumn => new("#F5B84A", "#E4A839", "autumn.png"),
        QuotaTheme.Apocalypse => new("#EF4A47", "#E14747", "apocalypse.png"),
        QuotaTheme.Wasteland => new("#C74A47", "#F0F0EA", "wasteland.png"),
        _ => throw new ArgumentOutOfRangeException(nameof(theme))
    };
}
