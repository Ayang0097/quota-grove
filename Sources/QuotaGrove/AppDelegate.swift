import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let quotaRefreshInterval: TimeInterval = 10

    private let source = LocalRateLimitSource()
    private let sourceQueue = DispatchQueue(label: "com.ayang.quotagrove.quota-source", qos: .utility)
    private let processMonitor = CodexProcessMonitor()
    private let weatherLinkManager = WeatherLinkManager()
    private var windowController: CardWindowController?
    private var refreshTimer: Timer?
    private var clockTimer: Timer?
    private var currentSnapshot: QuotaSnapshot?
    private var codexIsRunning = false
    private var refreshInProgress = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let controller = CardWindowController()
        windowController = controller
        currentSnapshot = QuotaSnapshotCache.load()
        updateCard()
        controller.onRefresh = { [weak self] in self?.refreshQuota(force: true) }
        controller.onWeatherLinkToggle = { [weak self] enabled in
            self?.weatherLinkManager.setEnabled(enabled)
        }
        weatherLinkManager.onChange = { [weak controller, weak weatherLinkManager] status, effect in
            guard let controller, let weatherLinkManager else { return }
            controller.setWeatherLink(enabled: weatherLinkManager.isEnabled, status: status)
            controller.setWeatherEffect(effect)
        }
        controller.setWeatherLink(enabled: weatherLinkManager.isEnabled, status: weatherLinkManager.status)

        if let demoValue = commandLineDemoValue() {
            codexIsRunning = true
            currentSnapshot = .demo(remainingPercent: demoValue)
            updateCard()
            if CommandLine.arguments.contains("--rain") {
                controller.setWeatherRainActive(true)
            } else if CommandLine.arguments.contains("--snow") {
                controller.setSnowEffectActive(true)
            }
            controller.showCard()
            return
        }

        weatherLinkManager.startIfEnabled()

        processMonitor.onChange = { [weak self] running in
            guard let self else { return }
            self.codexIsRunning = running
            if running {
                self.windowController?.showCard()
                self.refreshQuota(force: true)
            } else {
                self.windowController?.hideCard()
            }
        }
        processMonitor.start()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: Self.quotaRefreshInterval, repeats: true) { [weak self] _ in
            self?.refreshQuota(force: false)
        }
        if let refreshTimer { RunLoop.main.add(refreshTimer, forMode: .common) }

        clockTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.windowController?.refreshClock()
        }
        if let clockTimer { RunLoop.main.add(clockTimer, forMode: .common) }
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
        clockTimer?.invalidate()
        processMonitor.stop()
        weatherLinkManager.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func refreshQuota(force: Bool) {
        guard (codexIsRunning || force), !refreshInProgress else { return }
        refreshInProgress = true
        sourceQueue.async { [weak self] in
            guard let self else { return }
            let snapshot = autoreleasepool { self.source.latestSnapshot() }
            DispatchQueue.main.async {
                self.refreshInProgress = false
                if let snapshot,
                   self.currentSnapshot.map({ snapshot.fetchedAt >= $0.fetchedAt }) ?? true {
                    self.currentSnapshot = snapshot
                    QuotaSnapshotCache.save(snapshot)
                    self.updateCard()
                } else {
                    self.updateCard()
                }
            }
        }
    }

    private func updateCard() {
        windowController?.setSnapshot(currentSnapshot)
    }

    private func commandLineDemoValue() -> Double? {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--demo"), args.indices.contains(index + 1) else { return nil }
        return Double(args[index + 1])
    }
}
