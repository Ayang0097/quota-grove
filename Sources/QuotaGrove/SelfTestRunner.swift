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

        do {
            let line = Data(#"{"timestamp":"2026-08-27T07:48:05.500Z","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":31.0,"window_minutes":10080,"resets_at":1788405013},"secondary":{"used_percent":8,"window_minutes":300,"resets_at":1787810000},"plan_type":"prolite"}}}"#.utf8)
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
            expect(snapshot?.windowTitle == "5 小时额度", "实际窗口标题不得伪装成 7 天", report: &report)
        } catch {
            report.failures.append("实际窗口回退：\(error.localizedDescription)")
        }

        return report
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
