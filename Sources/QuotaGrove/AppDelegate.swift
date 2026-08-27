import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let source = LocalRateLimitSource()
    private let sourceQueue = DispatchQueue(label: "com.ayang.quotagrove.quota-source", qos: .utility)
    private let processMonitor = CodexProcessMonitor()
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

        if let demoValue = commandLineDemoValue() {
            codexIsRunning = true
            currentSnapshot = .demo(remainingPercent: demoValue)
            updateCard()
            controller.showCard()
            return
        }

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

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
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
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func refreshQuota(force: Bool) {
        guard codexIsRunning, !refreshInProgress else { return }
        refreshInProgress = true
        sourceQueue.async { [weak self] in
            guard let self else { return }
            let snapshot = autoreleasepool { self.source.latestSnapshot() }
            DispatchQueue.main.async {
                self.refreshInProgress = false
                if let snapshot {
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
