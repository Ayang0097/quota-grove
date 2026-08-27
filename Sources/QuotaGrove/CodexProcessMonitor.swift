import AppKit

final class CodexProcessMonitor {
    var onChange: ((Bool) -> Void)?

    private var timer: Timer?
    private var lastValue: Bool?

    func start() {
        evaluate()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.evaluate()
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func evaluate() {
        let running = NSWorkspace.shared.runningApplications.contains { application in
            guard application.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return false }
            let name = application.localizedName?.lowercased() ?? ""
            let bundleID = application.bundleIdentifier?.lowercased() ?? ""
            let path = application.bundleURL?.path.lowercased() ?? ""
            return name == "codex"
                || name == "chatgpt"
                || bundleID.contains("openai.codex")
                || bundleID == "com.openai.chat"
                || path.contains("/chatgpt.app/")
        }
        guard running != lastValue else { return }
        lastValue = running
        onChange?(running)
    }
}
