using System.Text.Json.Serialization;

namespace QuotaGrove.Core;

public sealed record QuotaSnapshot(
    int WindowMinutes,
    double RemainingPercent,
    double UsedPercent,
    DateTimeOffset? ResetsAt,
    DateTimeOffset FetchedAt,
    string Source,
    string? PlanType)
{
    [JsonIgnore]
    public int RoundedRemaining => (int)Math.Round(RemainingPercent, MidpointRounding.AwayFromZero);

    [JsonIgnore]
    public int RoundedUsed => (int)Math.Round(UsedPercent, MidpointRounding.AwayFromZero);

    [JsonIgnore]
    public string WindowTitle => AppText.WindowTitle(WindowMinutes);

    public string WindowTitleFor(AppLanguage language) => AppText.WindowTitle(WindowMinutes, language);

    [JsonIgnore]
    public string ReadablePlan
    {
        get
        {
            if (string.IsNullOrWhiteSpace(PlanType)) return "--";
            return PlanType.Trim().ToLowerInvariant() switch
            {
                "free" => "Free",
                "plus" => "Plus",
                "pro" => "Pro",
                "prolite" => "Pro Lite",
                "team" => "Team",
                "business" => "Business",
                "enterprise" => "Enterprise",
                "edu" => "Edu",
                _ => PlanType
            };
        }
    }

    public static QuotaSnapshot Demo(double remainingPercent)
    {
        var remaining = Math.Clamp(remainingPercent, 0, 100);
        return new QuotaSnapshot(
            10_080,
            remaining,
            100 - remaining,
            DateTimeOffset.Now.AddDays(6).AddHours(18),
            DateTimeOffset.Now.AddSeconds(-7),
            "preview",
            "prolite");
    }
}
