import AppKit
import Darwin
import Foundation

private func printSnapshot() -> Never {
    guard let snapshot = LocalRateLimitSource().latestSnapshot() else {
        FileHandle.standardError.write(Data("未找到可信额度事件\n".utf8))
        exit(2)
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    do {
        let data = try encoder.encode(snapshot)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("额度快照编码失败\n".utf8))
        exit(3)
    }
}

private func renderPreview(arguments: [String]) -> Never {
    guard
        let index = arguments.firstIndex(of: "--render-preview"),
        arguments.indices.contains(index + 2),
        let percent = Double(arguments[index + 1])
    else {
        FileHandle.standardError.write(Data("用法：QuotaGrove --render-preview <percent> <png-path> [--expanded]\n".utf8))
        exit(64)
    }

    let path = arguments[index + 2]
    let expanded = arguments.contains("--expanded")
    let stashed = arguments.contains("--stashed")
    let stashedEdge: StashedEdge = arguments.contains("--left") ? .left : .right
    _ = NSApplication.shared
    do {
        try PreviewRenderer.render(
            remainingPercent: percent,
            expanded: expanded,
            stashed: stashed,
            stashedEdge: stashedEdge,
            to: URL(fileURLWithPath: path)
        )
        print(path)
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("预览生成失败：\(error.localizedDescription)\n".utf8))
        exit(1)
    }
}

private func runSelfTests() -> Never {
    let report = SelfTestRunner.run()
    if report.succeeded {
        print("PASS \(report.passed) 项")
        exit(0)
    }
    print("FAIL \(report.failures.count) 项；PASS \(report.passed) 项")
    for failure in report.failures { print("- \(failure)") }
    exit(1)
}

let arguments = CommandLine.arguments
if arguments.contains("--self-test") {
    runSelfTests()
} else if arguments.contains("--snapshot-json") {
    printSnapshot()
} else if arguments.contains("--render-preview") {
    renderPreview(arguments: arguments)
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
