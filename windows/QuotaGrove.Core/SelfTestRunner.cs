namespace QuotaGrove.Core;

public sealed record SelfTestReport(int Passed, IReadOnlyList<string> Failures)
{
    public bool Succeeded => Failures.Count == 0;
}

public static class SelfTestRunner
{
    public static SelfTestReport Run()
    {
        var passed = 0;
        var failures = new List<string>();

        foreach (var (percent, expected) in new[]
        {
            (100d, QuotaTheme.Forest),
            (70d, QuotaTheme.Forest),
            (69d, QuotaTheme.Autumn),
            (40d, QuotaTheme.Autumn),
            (39d, QuotaTheme.Apocalypse),
            (10d, QuotaTheme.Apocalypse),
            (9d, QuotaTheme.Wasteland),
            (0d, QuotaTheme.Wasteland)
        })
        {
            Expect(QuotaThemes.Select(percent) == expected, $"主题边界 {percent}% 应为 {expected}");
        }

        Expect(QuotaThemes.Style(QuotaTheme.Autumn).AccentHex != QuotaThemes.Style(QuotaTheme.Forest).AccentHex, "秋季进度条不得使用森林绿");
        Expect(QuotaThemes.Style(QuotaTheme.Apocalypse).AccentHex != QuotaThemes.Style(QuotaTheme.Forest).AccentHex, "末日进度条不得使用森林绿");
        Expect(QuotaThemes.Style(QuotaTheme.Wasteland).AccentHex != QuotaThemes.Style(QuotaTheme.Forest).AccentHex, "废土进度条不得使用森林绿");
        Expect(QuotaThemes.Style(QuotaTheme.Wasteland).BorderHex != QuotaThemes.Style(QuotaTheme.Wasteland).AccentHex, "废土边框必须使用灰白色");

        const string valid = "{\"timestamp\":\"2026-08-27T07:48:05.500Z\",\"payload\":{\"type\":\"token_count\",\"rate_limits\":{\"limit_id\":\"codex\",\"primary\":{\"used_percent\":31.0,\"window_minutes\":10080,\"resets_at\":1788405013},\"secondary\":{\"used_percent\":8,\"window_minutes\":300,\"resets_at\":1787810000},\"plan_type\":\"prolite\"}}}";
        var snapshot = QuotaEventParser.ParseLine(valid);
        Expect(snapshot?.WindowMinutes == 10_080, "优先选择 7 天窗口");
        Expect(snapshot?.RemainingPercent == 69, "剩余百分比应由已用百分比计算");
        Expect(snapshot?.ReadablePlan == "Pro Lite", "可靠套餐字段应可读显示");
        Expect(snapshot?.ResetsAt?.ToUnixTimeSeconds() == 1_788_405_013, "Unix 重置时间应正确解析");

        Expect(QuotaEventParser.ParseLine("{\"payload\":{\"type\":\"message\"}}") is null, "无关事件必须忽略");

        const string modelSpecific = "{\"timestamp\":\"2026-08-27T14:08:32.668Z\",\"payload\":{\"type\":\"token_count\",\"rate_limits\":{\"limit_id\":\"codex_bengalfox\",\"limit_name\":\"GPT-5.3-Codex-Spark\",\"primary\":{\"used_percent\":0,\"window_minutes\":300},\"secondary\":{\"used_percent\":0,\"window_minutes\":10080},\"plan_type\":\"prolite\"}}}";
        Expect(QuotaEventParser.ParseLine(modelSpecific) is null, "单独模型额度不得覆盖 Codex 总额度");

        try
        {
            _ = QuotaEventParser.ParseLine("{\"payload\":{\"rate_limits\":{\"primary\":{\"used_percent\":101,\"window_minutes\":10080}}}}");
            failures.Add("异常百分比必须拒绝");
        }
        catch (QuotaParseException)
        {
            passed++;
        }

        const string fallback = "{\"payload\":{\"rate_limits\":{\"primary\":{\"used_percent\":20,\"window_minutes\":60},\"secondary\":{\"used_percent\":40,\"window_minutes\":300}}}}";
        var fallbackSnapshot = QuotaEventParser.ParseLine(fallback);
        Expect(fallbackSnapshot?.WindowMinutes == 300, "缺少 7 天窗口时选择最长实际窗口");
        Expect(fallbackSnapshot?.WindowTitleFor(AppLanguage.Chinese) == "5 小时额度", "实际窗口标题不得伪装成 7 天");

        Expect(AppText.Resolve(["zh-CN"]) == AppLanguage.Chinese, "简体中文系统应显示中文");
        Expect(AppText.Resolve(["zh-Hant-TW"]) == AppLanguage.Chinese, "繁体中文系统应显示中文");
        Expect(AppText.Resolve(["en-US"]) == AppLanguage.English, "英文系统应显示英文");
        Expect(AppText.Resolve([]) == AppLanguage.English, "未知系统语言应安全回退英文");
        Expect(AppText.WindowTitle(10_080, AppLanguage.Chinese) == "7 天额度", "中文额度标题应正确");
        Expect(AppText.WindowTitle(10_080, AppLanguage.English) == "7-day quota", "英文额度标题应正确");
        Expect(AppText.QuotaUsage(54, 46, AppLanguage.Chinese) == "剩余 54% · 已用 46%", "中文额度详情应正确");
        Expect(AppText.QuotaUsage(54, 46, AppLanguage.English) == "54% left · 46% used", "英文额度详情应正确");

        TestLargeLogLookup();

        return new SelfTestReport(passed, failures);

        void Expect(bool condition, string message)
        {
            if (condition) passed++;
            else failures.Add(message);
        }

        void TestLargeLogLookup()
        {
            var directory = Path.Combine(Path.GetTempPath(), $"quota-grove-source-test-{Guid.NewGuid():N}");
            try
            {
                Directory.CreateDirectory(directory);
                var freshPath = Path.Combine(directory, "fresh.jsonl");
                var stalePath = Path.Combine(directory, "stale.jsonl");
                const string freshEvent = "{\"timestamp\":\"2026-08-28T06:00:00.000Z\",\"payload\":{\"type\":\"token_count\",\"rate_limits\":{\"limit_id\":\"codex\",\"primary\":{\"used_percent\":7,\"window_minutes\":10080}}}}";
                const string staleEvent = "{\"timestamp\":\"2026-08-27T14:47:00.000Z\",\"payload\":{\"type\":\"token_count\",\"rate_limits\":{\"limit_id\":\"codex\",\"primary\":{\"used_percent\":72,\"window_minutes\":10080}}}}";
                var filler = string.Concat(Enumerable.Repeat("{\"payload\":{\"type\":\"message\",\"text\":\"padding\"}}\n", 7_000));
                File.WriteAllText(freshPath, freshEvent + "\n" + filler);
                File.WriteAllText(stalePath, staleEvent + "\n");
                File.SetLastWriteTimeUtc(freshPath, DateTime.UtcNow);
                File.SetLastWriteTimeUtc(stalePath, DateTime.UtcNow.AddMinutes(-1));

                var discovered = new LocalRateLimitSource([directory]).LatestSnapshot();
                Expect(discovered?.RemainingPercent == 93, "大日志尾部没有额度事件时不得回退到旧文件的 28%");
            }
            catch (Exception error) when (error is IOException or UnauthorizedAccessException)
            {
                failures.Add($"大日志额度回归测试：{error.Message}");
            }
            finally
            {
                try { if (Directory.Exists(directory)) Directory.Delete(directory, recursive: true); }
                catch (IOException) { }
                catch (UnauthorizedAccessException) { }
            }
        }
    }
}
