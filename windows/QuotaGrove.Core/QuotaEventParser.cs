using System.Globalization;
using System.Text.Json;

namespace QuotaGrove.Core;

public sealed class QuotaParseException(string message) : Exception(message);

public static class QuotaEventParser
{
    public static QuotaSnapshot? ParseLine(string line)
    {
        if (!line.Contains("\"rate_limits\"", StringComparison.Ordinal)) return null;

        using var document = JsonDocument.Parse(line);
        var root = document.RootElement;
        if (!TryObject(root, "payload", out var payload) ||
            !TryObject(payload, "rate_limits", out var limits))
        {
            return null;
        }

        // Codex can emit separate rate-limit events for individual models.
        // Quota Grove represents the account-wide Codex quota, so those
        // model-specific limits must not replace the overall value.
        if (limits.TryGetProperty("limit_id", out var limitIdValue) &&
            limitIdValue.ValueKind == JsonValueKind.String)
        {
            var limitId = limitIdValue.GetString();
            if (!string.IsNullOrEmpty(limitId) &&
                !string.Equals(limitId, "codex", StringComparison.Ordinal))
            {
                return null;
            }
        }

        var windows = new List<RateLimitWindow>(2);
        foreach (var key in new[] { "primary", "secondary" })
        {
            if (TryObject(limits, key, out var value) && TryReadWindow(value, out var window))
            {
                windows.Add(window);
            }
        }

        if (windows.Count == 0) throw new QuotaParseException("额度事件缺少可用窗口");
        var selected = windows.FirstOrDefault(window => window.WindowMinutes == 10_080)
            ?? windows.MaxBy(window => window.WindowMinutes)!;
        if (!double.IsFinite(selected.UsedPercent) || selected.UsedPercent is < 0 or > 100)
        {
            throw new QuotaParseException("额度事件包含异常百分比");
        }

        var fetchedAt = DateTimeOffset.Now;
        if (root.TryGetProperty("timestamp", out var timestampValue) &&
            timestampValue.ValueKind == JsonValueKind.String &&
            DateTimeOffset.TryParse(timestampValue.GetString(), CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var parsedTimestamp))
        {
            fetchedAt = parsedTimestamp;
        }

        string? planType = null;
        if (limits.TryGetProperty("plan_type", out var planValue) && planValue.ValueKind == JsonValueKind.String)
        {
            planType = planValue.GetString();
        }

        return new QuotaSnapshot(
            selected.WindowMinutes,
            100 - selected.UsedPercent,
            selected.UsedPercent,
            selected.ResetsAt is { } resetEpoch ? DateTimeOffset.FromUnixTimeSeconds((long)resetEpoch) : null,
            fetchedAt,
            "codex-local-event",
            planType);
    }

    private static bool TryObject(JsonElement parent, string key, out JsonElement value)
    {
        if (parent.ValueKind == JsonValueKind.Object &&
            parent.TryGetProperty(key, out value) &&
            value.ValueKind == JsonValueKind.Object)
        {
            return true;
        }
        value = default;
        return false;
    }

    private static bool TryReadWindow(JsonElement value, out RateLimitWindow window)
    {
        window = default!;
        if (!TryDouble(value, "used_percent", out var usedPercent) ||
            !TryInt(value, "window_minutes", out var windowMinutes) ||
            windowMinutes <= 0)
        {
            return false;
        }

        _ = TryDouble(value, "resets_at", out var resetsAt);
        window = new RateLimitWindow(usedPercent, windowMinutes, resetsAt == 0 ? null : resetsAt);
        return true;
    }

    private static bool TryDouble(JsonElement parent, string key, out double value)
    {
        value = 0;
        return parent.TryGetProperty(key, out var element) &&
            element.ValueKind == JsonValueKind.Number &&
            element.TryGetDouble(out value);
    }

    private static bool TryInt(JsonElement parent, string key, out int value)
    {
        value = 0;
        return parent.TryGetProperty(key, out var element) &&
            element.ValueKind == JsonValueKind.Number &&
            element.TryGetInt32(out value);
    }

    private sealed record RateLimitWindow(double UsedPercent, int WindowMinutes, double? ResetsAt);
}
