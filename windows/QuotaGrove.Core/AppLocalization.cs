using System.Globalization;

namespace QuotaGrove.Core;

public enum AppLanguage
{
    Chinese,
    English
}

public static class AppText
{
    public static AppLanguage CurrentLanguage => Resolve([CultureInfo.CurrentUICulture.Name]);

    public static AppLanguage Resolve(IEnumerable<string> preferredLanguages)
    {
        var primary = preferredLanguages.FirstOrDefault();
        if (string.IsNullOrWhiteSpace(primary)) return AppLanguage.English;
        var normalized = primary.Replace('_', '-').ToLowerInvariant();
        return normalized == "zh" || normalized.StartsWith("zh-", StringComparison.Ordinal)
            ? AppLanguage.Chinese
            : AppLanguage.English;
    }

    public static string Localized(string chinese, string english, AppLanguage? language = null) =>
        (language ?? CurrentLanguage) == AppLanguage.Chinese ? chinese : english;

    public static string WindowTitle(int minutes, AppLanguage? language = null)
    {
        if (minutes == 10_080) return Localized("7 天额度", "7-day quota", language);
        if (minutes % 1_440 == 0)
        {
            var days = minutes / 1_440;
            return Localized($"{days} 天额度", $"{days}-day quota", language);
        }
        if (minutes % 60 == 0)
        {
            var hours = minutes / 60;
            return Localized($"{hours} 小时额度", $"{hours}-hour quota", language);
        }
        return Localized($"{minutes} 分钟额度", $"{minutes}-minute quota", language);
    }

    public static string SevenDayQuota => Localized("7 天额度", "7-day quota");
    public static string Remaining => Localized("剩余", "Remaining");
    public static string WaitingForQuota => Localized("等待额度数据", "Waiting for quota data");
    public static string ResetTimeUnknown => Localized("重置时间未知", "Reset time unknown");
    public static string ResettingSoon => Localized("即将重置", "Resetting soon");
    public static string TimeToReset => Localized("距离重置", "Time to reset");
    public static string SubscriptionPlan => Localized("订阅计划", "Plan");
    public static string DataUpdated => Localized("数据更新", "Updated");
    public static string NoData => Localized("暂无数据", "No data");

    public static string QuotaUsage(int remaining, int used, AppLanguage? language = null) =>
        Localized($"剩余 {remaining}% · 已用 {used}%", $"{remaining}% left · {used}% used", language);

    public static string ResetCountdown(int days, int hours, int minutes, bool includeResetPrefix, AppLanguage? language = null)
    {
        if ((language ?? CurrentLanguage) == AppLanguage.Chinese)
        {
            var value = days > 0 ? $"{days} 天 {hours} 小时" : $"{hours} 小时 {minutes} 分钟";
            return includeResetPrefix ? $"{value}后重置" : value;
        }
        var englishValue = days > 0 ? $"{days}d {hours}h" : $"{hours}h {minutes}m";
        return includeResetPrefix ? $"Resets in {englishValue}" : englishValue;
    }

    public static string DataAge(TimeSpan age, AppLanguage? language = null)
    {
        var selected = language ?? CurrentLanguage;
        if (age.TotalSeconds < 60)
        {
            var seconds = Math.Max(0, (int)age.TotalSeconds);
            return selected == AppLanguage.Chinese ? $"{seconds} 秒前" : $"{seconds}s ago";
        }
        if (age.TotalMinutes < 60)
        {
            var minutes = (int)age.TotalMinutes;
            return selected == AppLanguage.Chinese ? $"{minutes} 分钟前" : $"{minutes}m ago";
        }
        if (age.TotalHours < 24)
        {
            var hours = (int)age.TotalHours;
            return selected == AppLanguage.Chinese ? $"{hours} 小时前" : $"{hours}h ago";
        }
        var days = (int)age.TotalDays;
        return selected == AppLanguage.Chinese ? $"{days} 天前" : $"{days}d ago";
    }

    public static string ThemeAccessibilityName(QuotaTheme theme) => theme switch
    {
        QuotaTheme.Forest => Localized("额度充足", "Quota available"),
        QuotaTheme.Autumn => Localized("额度偏低", "Quota running low"),
        QuotaTheme.Apocalypse => Localized("额度紧张", "Quota nearly depleted"),
        QuotaTheme.Wasteland => Localized("额度即将耗尽", "Quota almost exhausted"),
        _ => NoData
    };

    public static string RefreshQuota => Localized("刷新额度", "Refresh quota");
    public static string LaunchAtLogin => Localized("登录时启动", "Launch at login");
    public static string ResetCardPosition => Localized("重置卡片位置", "Reset card position");
    public static string AboutAndPrivacy => Localized("关于与隐私", "About & privacy");
    public static string Quit => Localized("退出 Quota Grove", "Quit Quota Grove");
    public static string LaunchUpdateFailed => Localized("无法更新登录启动", "Couldn’t update launch at login");
    public static string AboutTitle => Localized("Quota Grove · 额度森林", "Quota Grove");
    public static string AboutMessage => Localized(
        "非官方本机工具，与 OpenAI 无隶属或背书关系。\n\n工具只读取本机 Codex 运行事件中的额度字段，不读取账号凭据，不上传数据，也不包含遥测。",
        "An unofficial local utility with no affiliation with or endorsement by OpenAI.\n\nIt only reads quota fields from local Codex runtime events. It does not read account credentials, upload data, or include telemetry.");
    public static string MissingExecutable => Localized("无法打开当前用户的登录启动设置", "Couldn’t open the current user’s launch-at-login settings");

    public static string AccessibilityName(string title, int? remaining, QuotaTheme? theme, bool isStashed, bool isExpanded)
    {
        var percent = remaining is { } value ? Localized($"剩余 {value}%", $"{value}% remaining") : WaitingForQuota;
        var state = theme is { } selectedTheme ? ThemeAccessibilityName(selectedTheme) : NoData;
        var mode = isStashed
            ? Localized("已收纳，悬停显示完整卡片", "Stashed. Hover to reveal the full card")
            : isExpanded
                ? Localized("单击收起，双击刷新", "Click to collapse. Double-click to refresh")
                : Localized("单击展开，双击刷新", "Click to expand. Double-click to refresh");
        return Localized(
            $"{title}，{percent}，{state}。{mode}。",
            $"{title}, {percent}, {state}. {mode}.");
    }

    public static string AccessibilityHelp => Localized(
        "可拖动卡片；拖到屏幕左侧或右侧可收纳。右键打开菜单。",
        "Drag the card to move it. Drag to either screen edge to stash it. Right-click to open the menu.");
}
