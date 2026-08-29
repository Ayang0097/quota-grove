import AppKit
import Darwin
import Foundation

private func applyPreviewBackgroundStyle(arguments: [String]) {
    guard
        let index = arguments.firstIndex(of: "--background-style"),
        arguments.indices.contains(index + 1),
        let style = CardBackgroundStyle(rawValue: arguments[index + 1]),
        CardBackgroundStyle.builtInStyles.contains(style)
    else { return }
    ThemeBackgroundStore.shared.setSessionStyleOverride(style)
}

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

private func printWeather(arguments: [String]) -> Never {
    guard
        let index = arguments.firstIndex(of: "--weather-json"),
        arguments.indices.contains(index + 2),
        let latitude = Double(arguments[index + 1]),
        let longitude = Double(arguments[index + 2])
    else {
        FileHandle.standardError.write(Data("用法：QuotaGrove --weather-json <latitude> <longitude>\n".utf8))
        exit(64)
    }

    let coordinate = CoarseWeatherCoordinate.rounded(latitude: latitude, longitude: longitude)
    let semaphore = DispatchSemaphore(value: 0)
    var result: Result<WeatherObservation, Error>?
    let client = WeatherClient()
    _ = client.fetchCurrent(at: coordinate) { response in
        result = response
        semaphore.signal()
    }
    guard semaphore.wait(timeout: .now() + 20) == .success, let result else {
        FileHandle.standardError.write(Data("天气请求超时\n".utf8))
        exit(2)
    }

    switch result {
    case let .success(observation):
        let object: [String: Any] = [
            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude,
            "weatherCode": observation.weatherCode,
            "rain": observation.rain,
            "showers": observation.showers,
            "snowfall": observation.snowfall,
            "effect": observation.effect.rawValue,
            "isRaining": observation.isRaining,
            "isSnowing": observation.isSnowing
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data("\n".utf8))
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("天气结果编码失败\n".utf8))
            exit(3)
        }
    case let .failure(error):
        FileHandle.standardError.write(Data("天气请求失败：\(error.localizedDescription)\n".utf8))
        exit(1)
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
    applyPreviewBackgroundStyle(arguments: arguments)
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

private func renderLeafFrames(arguments: [String]) -> Never {
    guard
        let index = arguments.firstIndex(of: "--render-leaf-frames"),
        arguments.indices.contains(index + 3),
        let startPercent = Double(arguments[index + 1]),
        let endPercent = Double(arguments[index + 2])
    else {
        FileHandle.standardError.write(Data("用法：QuotaGrove --render-leaf-frames <from-percent> <to-percent> <directory> [--expanded] [--manual-burst]\n".utf8))
        exit(64)
    }

    applyPreviewBackgroundStyle(arguments: arguments)
    _ = NSApplication.shared
    do {
        let directory = URL(fileURLWithPath: arguments[index + 3], isDirectory: true)
        try PreviewRenderer.renderLeafFrames(
            from: startPercent,
            to: endPercent,
            expanded: arguments.contains("--expanded"),
            manualBurst: arguments.contains("--manual-burst"),
            to: directory
        )
        print(directory.path)
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("落叶预览生成失败：\(error.localizedDescription)\n".utf8))
        exit(1)
    }
}

private func renderRainFrames(arguments: [String]) -> Never {
    guard
        let index = arguments.firstIndex(of: "--render-rain-frames"),
        arguments.indices.contains(index + 2),
        let percent = Double(arguments[index + 1])
    else {
        FileHandle.standardError.write(Data("用法：QuotaGrove --render-rain-frames <percent> <directory> [--expanded]\n".utf8))
        exit(64)
    }

    applyPreviewBackgroundStyle(arguments: arguments)
    _ = NSApplication.shared
    do {
        let directory = URL(fileURLWithPath: arguments[index + 2], isDirectory: true)
        try PreviewRenderer.renderRainFrames(
            remainingPercent: percent,
            expanded: arguments.contains("--expanded"),
            to: directory
        )
        print(directory.path)
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("下雨预览生成失败：\(error.localizedDescription)\n".utf8))
        exit(1)
    }
}

private func renderSnowFrames(arguments: [String]) -> Never {
    guard
        let index = arguments.firstIndex(of: "--render-snow-frames"),
        arguments.indices.contains(index + 2),
        let percent = Double(arguments[index + 1])
    else {
        FileHandle.standardError.write(Data("用法：QuotaGrove --render-snow-frames <percent> <directory> [--expanded]\n".utf8))
        exit(64)
    }

    applyPreviewBackgroundStyle(arguments: arguments)
    _ = NSApplication.shared
    do {
        let directory = URL(fileURLWithPath: arguments[index + 2], isDirectory: true)
        try PreviewRenderer.renderSnowFrames(
            remainingPercent: percent,
            expanded: arguments.contains("--expanded"),
            to: directory
        )
        print(directory.path)
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("下雪预览生成失败：\(error.localizedDescription)\n".utf8))
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
} else if arguments.contains("--weather-json") {
    printWeather(arguments: arguments)
} else if arguments.contains("--render-snow-frames") {
    renderSnowFrames(arguments: arguments)
} else if arguments.contains("--render-rain-frames") {
    renderRainFrames(arguments: arguments)
} else if arguments.contains("--render-leaf-frames") {
    renderLeafFrames(arguments: arguments)
} else if arguments.contains("--render-preview") {
    renderPreview(arguments: arguments)
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
