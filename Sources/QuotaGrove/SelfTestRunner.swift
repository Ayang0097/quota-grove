import Foundation

enum SelfTestRunner {
    struct Report {
        var passed = 0
        var failures: [String] = []

        var succeeded: Bool { failures.isEmpty }
    }

    static func run() -> Report {
        var report = Report()

        let boundaries: [(Double, QuotaTheme)] = [
            (50, .forest),
            (49, .autumn),
            (20, .autumn),
            (19, .apocalypse),
            (3, .apocalypse),
            (2, .wasteland),
            (1, .wasteland),
            (0, .wasteland)
        ]
        for (percent, expected) in boundaries {
            expect(
                QuotaTheme.select(for: percent) == expected,
                "主题边界 \(percent)% 应为 \(expected.rawValue)",
                report: &report
            )
        }

        expect(QuotaTheme.autumn.accent != QuotaTheme.forest.accent, "秋季进度条不得使用森林绿", report: &report)
        expect(QuotaTheme.apocalypse.accent != QuotaTheme.forest.accent, "末日进度条不得使用森林绿", report: &report)
        expect(QuotaTheme.wasteland.accent != QuotaTheme.forest.accent, "废土进度条不得使用森林绿", report: &report)
        expect(QuotaTheme.wasteland.borderAccent != QuotaTheme.wasteland.accent, "废土边框必须使用灰白色并与红色进度警示区分", report: &report)
        expect(QuotaTheme.forest.progressAccent != QuotaTheme.forest.accent, "森林进度条应使用比边框更鲜明的绿色", report: &report)
        expect(QuotaTheme.autumn.progressAccent == QuotaTheme.autumn.accent, "森林之外的主题应保留原有进度色", report: &report)
        expect(QuotaCardView.ambientLeafInterval == 3, "环境落叶应每 3 秒检查并播放一次", report: &report)

        do {
            let line = Data(#"{"timestamp":"2026-08-27T07:48:05.500Z","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":31.0,"window_minutes":10080,"resets_at":1788405013},"secondary":{"used_percent":8,"window_minutes":300,"resets_at":1787810000},"plan_type":"prolite"}}}"#.utf8)
            let snapshot = try QuotaEventParser.parse(line: line)
            expect(snapshot?.windowMinutes == 10_080, "优先选择 7 天窗口", report: &report)
            expect(snapshot?.remainingPercent == 69, "剩余百分比应由已用百分比计算", report: &report)
            expect(snapshot?.readablePlan == "Pro Lite", "可靠套餐字段应可读显示", report: &report)
            expect(snapshot?.resetsAt?.timeIntervalSince1970 == 1_788_405_013, "Unix 重置时间应正确解析", report: &report)
        } catch {
            report.failures.append("解析合法 7 天额度事件：\(error.localizedDescription)")
        }

        let unrelated = Data(#"{"payload":{"type":"message","text":"not quota data"}}"#.utf8)
        expect(try QuotaEventParser.parse(line: unrelated) == nil, "无关事件必须忽略", report: &report)

        let modelSpecific = Data(#"{"timestamp":"2026-08-27T14:08:32.668Z","payload":{"type":"token_count","rate_limits":{"limit_id":"codex_bengalfox","limit_name":"GPT-5.3-Codex-Spark","primary":{"used_percent":0,"window_minutes":300},"secondary":{"used_percent":0,"window_minutes":10080},"plan_type":"prolite"}}}"#.utf8)
        expect(try QuotaEventParser.parse(line: modelSpecific) == nil, "单独模型额度不得覆盖 Codex 总额度", report: &report)

        do {
            let invalid = Data(#"{"payload":{"rate_limits":{"primary":{"used_percent":101,"window_minutes":10080}}}}"#.utf8)
            _ = try QuotaEventParser.parse(line: invalid)
            report.failures.append("异常百分比必须拒绝")
        } catch {
            report.passed += 1
        }

        do {
            let fallback = Data(#"{"payload":{"rate_limits":{"primary":{"used_percent":20,"window_minutes":60},"secondary":{"used_percent":40,"window_minutes":300}}}}"#.utf8)
            let snapshot = try QuotaEventParser.parse(line: fallback)
            expect(snapshot?.windowMinutes == 300, "缺少 7 天窗口时选择最长实际窗口", report: &report)
            expect(snapshot?.windowTitle(language: .chinese) == "5 小时额度", "实际窗口标题不得伪装成 7 天", report: &report)
        } catch {
            report.failures.append("实际窗口回退：\(error.localizedDescription)")
        }

        expect(AppLanguage.resolve(preferredLanguages: ["zh-CN"]) == .chinese, "简体中文系统应显示中文", report: &report)
        expect(AppLanguage.resolve(preferredLanguages: ["zh-Hant-TW"]) == .chinese, "繁体中文系统应显示中文", report: &report)
        expect(AppLanguage.resolve(preferredLanguages: ["en-US"]) == .english, "英文系统应显示英文", report: &report)
        expect(AppLanguage.resolve(preferredLanguages: []) == .english, "未知系统语言应安全回退英文", report: &report)
        expect(AppText.windowTitle(minutes: 10_080, language: .chinese) == "7 天额度", "中文额度标题应正确", report: &report)
        expect(AppText.windowTitle(minutes: 10_080, language: .english) == "7-day quota", "英文额度标题应正确", report: &report)
        expect(AppText.quotaUsage(remaining: 54, used: 46, language: .chinese) == "剩余 54% · 已用 46%", "中文额度详情应正确", report: &report)
        expect(AppText.quotaUsage(remaining: 54, used: 46, language: .english) == "54% left · 46% used", "英文额度详情应正确", report: &report)

        testLargeLogLookup(report: &report)

        let coarseCoordinate = CoarseWeatherCoordinate.rounded(latitude: 31.230_416, longitude: 121.473_701)
        expect(coarseCoordinate.latitude == 31.23 && coarseCoordinate.longitude == 121.47, "天气定位只保留两位小数", report: &report)
        expect(WeatherConditionEvaluator.isRaining(weatherCode: 51, rain: 0, showers: 0), "毛毛雨天气码应开启雨效", report: &report)
        expect(WeatherConditionEvaluator.isRaining(weatherCode: 80, rain: 0, showers: 0), "阵雨天气码应开启雨效", report: &report)
        expect(WeatherConditionEvaluator.isRaining(weatherCode: 3, rain: 0.2, showers: 0), "实时雨量大于零时应开启雨效", report: &report)
        expect(!WeatherConditionEvaluator.isRaining(weatherCode: 71, rain: 0, showers: 0), "纯降雪不得误判为下雨", report: &report)
        expect(
            WeatherConditionEvaluator.effect(weatherCode: 71, rain: 0, showers: 0, snowfall: 0) == .snow,
            "降雪天气码应开启雪效",
            report: &report
        )
        expect(
            WeatherConditionEvaluator.effect(weatherCode: 61, rain: 0.2, showers: 0, snowfall: 0.1) == .snow,
            "雨雪混合时应优先显示雪效",
            report: &report
        )
        do {
            let weatherData = Data(#"{"current":{"weather_code":63,"rain":0.4,"showers":0}}"#.utf8)
            let observation = try WeatherClient.decode(data: weatherData)
            expect(observation.isRaining && observation.weatherCode == 63, "Open-Meteo 当前天气响应应正确解析", report: &report)
        } catch {
            report.failures.append("天气响应解析：\(error.localizedDescription)")
        }

        var rain = RainParticleSystem()
        rain.start(in: CGSize(width: 200, height: 80))
        expect(rain.drops.count == 52, "雨效应使用 52 滴分层细雨", report: &report)
        expect(rain.drops.allSatisfy { $0.windSpeed < 0 }, "雨滴应统一向左下方倾斜", report: &report)
        expect(rain.drops.allSatisfy { $0.lineWidth < 0.5 }, "雨滴线宽应保持细腻", report: &report)
        expect(
            rain.drops.contains { $0.depth < 0.36 }
                && rain.drops.contains { $0.depth > 0.4 && $0.depth < 0.75 }
                && rain.drops.contains { $0.depth > 0.77 },
            "雨效应包含远中近三层景深",
            report: &report
        )

        var snow = SnowParticleSystem()
        snow.start(in: CGSize(width: 200, height: 80))
        expect(snow.flakes.count == 20, "雪效应使用 20 片树枝状分层雪花", report: &report)
        expect(snow.flakes.allSatisfy { $0.fallSpeed > 0 }, "雪花应稳定受重力向下飘落", report: &report)
        expect(
            snow.flakes.contains { $0.depth < 0.36 }
                && snow.flakes.contains { $0.depth > 0.4 && $0.depth < 0.75 }
                && snow.flakes.contains { $0.depth > 0.77 },
            "雪效应包含远中近三层景深",
            report: &report
        )
        let farSnowSize = snow.flakes.filter { $0.depth < 0.36 }.map(\.size).max() ?? 0
        let nearSnowSize = snow.flakes.filter { $0.depth > 0.77 }.map(\.size).min() ?? 0
        expect(nearSnowSize > farSnowSize, "近景雪花应明显大于远景雪花", report: &report)
        let initialSnowPositions = snow.flakes.map(\.position)
        snow.advance(by: 1.0 / 20.0, in: CGSize(width: 200, height: 80))
        expect(snow.flakes.map(\.position) != initialSnowPositions, "雪花应具有持续飘落运动", report: &report)

        var onePointDrop = LeafParticleSystem()
        onePointDrop.emit(forPercentageDrop: 1, in: CGSize(width: 200, height: 80))
        expect(onePointDrop.leaves.count == 8, "每下降 1% 应生成 8 片轻量落叶", report: &report)
        let depthBands = Set(onePointDrop.leaves.map { Int($0.depth * 10) })
        expect(depthBands.count >= 3, "同组落叶应覆盖远中近至少 3 层景深", report: &report)
        expect(onePointDrop.leaves.filter { $0.focus == .crisp }.count == 2, "每组落叶应保留 2 片清晰叶片", report: &report)
        expect(onePointDrop.leaves.filter { $0.focus == .soft }.count == 2, "每组落叶应包含 2 片景深虚化叶片", report: &report)
        expect(onePointDrop.leaves.filter { $0.focus == .motion }.count == 4, "每组落叶应包含 4 片方向模糊叶片", report: &report)
        expect(onePointDrop.leaves.allSatisfy { $0.position.x >= 120 }, "落叶的初始构图应集中在卡片右侧", report: &report)

        var threePointDrop = LeafParticleSystem()
        threePointDrop.emit(forPercentageDrop: 3, in: CGSize(width: 200, height: 80))
        expect(threePointDrop.leaves.count == 24, "连续下降百分比应按组生成落叶", report: &report)

        for _ in 0..<15 { onePointDrop.advance(by: 1.0 / 30.0) }
        expect(onePointDrop.visibleCount > 0, "落叶延迟结束后应进入可见状态", report: &report)

        var largeDrop = LeafParticleSystem()
        largeDrop.emit(forPercentageDrop: 100, in: CGSize(width: 200, height: 80))
        expect(largeDrop.leaves.count == 32, "大幅跳变应限制同时动画密度", report: &report)

        var manualBurst = LeafParticleSystem()
        manualBurst.emitManualBurst(in: CGSize(width: 200, height: 80))
        expect(manualBurst.leaves.count == 48, "双击卡片应生成 48 片大量落叶", report: &report)
        expect(LeafParticleSystem.manualBurstWaveCounts == [4, 10, 19, 10, 5], "双击落叶应按先少后多再少的密度落下", report: &report)
        expect(manualBurst.leaves.allSatisfy { $0.position.x >= 144 }, "双击落叶应统一从卡片右上方进入", report: &report)
        expect(manualBurst.leaves.allSatisfy { $0.windVelocityX < 0 }, "双击落叶应受到向左的风场牵引", report: &report)
        expect(manualBurst.leaves.allSatisfy { abs($0.velocity.dx) < 24 }, "双击落叶应以低初速进入而非被抛出", report: &report)
        expect(
            manualBurst.leaves.contains { $0.midSpreadY < -20 }
                && manualBurst.leaves.contains { $0.midSpreadY > 20 },
            "双击落叶中段应同时包含上托与下沉分层",
            report: &report
        )
        expect(manualBurst.leaves.filter { $0.focus == .crisp }.count == 12, "双击落叶应保留 12 片清晰叶片", report: &report)
        expect(manualBurst.leaves.allSatisfy { $0.verticalAcceleration >= 34 }, "双击落叶应具有自然重力加速度", report: &report)
        var departingLeaf = manualBurst.leaves[0]
        expect(departingLeaf.departureProgress(in: 80) == 0, "落叶进入卡片时不应提前退场", report: &report)
        departingLeaf.position.y = 1.6
        expect(departingLeaf.departureProgress(in: 80) > 0.99, "落叶接近底部时应完成景深退场", report: &report)

        return report
    }

    private static func testLargeLogLookup(report: inout Report) {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("quota-grove-source-test-\(UUID().uuidString)", isDirectory: true)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? fileManager.removeItem(at: directory) }

            let freshURL = directory.appendingPathComponent("fresh.jsonl")
            let staleURL = directory.appendingPathComponent("stale.jsonl")
            let freshEvent = #"{"timestamp":"2026-08-28T06:00:00.000Z","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":7,"window_minutes":10080}}}}"#
            let staleEvent = #"{"timestamp":"2026-08-27T14:47:00.000Z","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":72,"window_minutes":10080}}}}"#
            let fillerLine = #"{"payload":{"type":"message","text":"padding"}}"# + "\n"
            let freshData = Data((freshEvent + "\n" + String(repeating: fillerLine, count: 7_000)).utf8)
            try freshData.write(to: freshURL)
            try Data((staleEvent + "\n").utf8).write(to: staleURL)
            try fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: freshURL.path)
            try fileManager.setAttributes([.modificationDate: Date().addingTimeInterval(-60)], ofItemAtPath: staleURL.path)

            let snapshot = LocalRateLimitSource(root: directory, fileManager: fileManager).latestSnapshot()
            expect(snapshot?.remainingPercent == 93, "大日志尾部没有额度事件时不得回退到旧文件的 28%", report: &report)
        } catch {
            report.failures.append("大日志额度回归测试：\(error.localizedDescription)")
        }
    }

    private static func expect(_ condition: @autoclosure () throws -> Bool, _ message: String, report: inout Report) {
        do {
            if try condition() {
                report.passed += 1
            } else {
                report.failures.append(message)
            }
        } catch {
            report.failures.append("\(message)：\(error.localizedDescription)")
        }
    }
}
