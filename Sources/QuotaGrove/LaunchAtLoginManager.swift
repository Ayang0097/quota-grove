import Foundation

final class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()

    private let label = "com.ayang.quotagrove"

    private var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(label).plist")
    }

    var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            guard let executable = Bundle.main.executableURL else {
                throw LaunchError.missingExecutable
            }
            let directory = plistURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let plist: [String: Any] = [
                "Label": label,
                "ProgramArguments": [executable.path],
                "RunAtLoad": true,
                "ProcessType": "Interactive"
            ]
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: plistURL, options: .atomic)
        } else {
            try? bootOut()
            if FileManager.default.fileExists(atPath: plistURL.path) {
                try FileManager.default.removeItem(at: plistURL)
            }
        }
    }

    private func bootOut() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["bootout", "gui/\(getuid())/\(label)"]
        try process.run()
        process.waitUntilExit()
    }

    enum LaunchError: LocalizedError {
        case missingExecutable

        var errorDescription: String? {
            "无法确定应用可执行文件位置"
        }
    }
}
