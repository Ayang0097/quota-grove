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
    public string WindowTitle => WindowMinutes switch
    {
        10_080 => "7 天额度",
        _ when WindowMinutes % 1_440 == 0 => $"{WindowMinutes / 1_440} 天额度",
        _ when WindowMinutes % 60 == 0 => $"{WindowMinutes / 60} 小时额度",
        _ => $"{WindowMinutes} 分钟额度"
    };

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
