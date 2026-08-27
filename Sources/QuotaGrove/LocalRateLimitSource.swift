import Foundation

final class LocalRateLimitSource {
    private let root: URL
    private let fileManager: FileManager
    private var candidates: [URL] = []
    private var lastDiscovery = Date.distantPast
    private var candidateDirectoryModificationDate: Date?
    private let tailLimit = 256 * 1_024

    init(
        root: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions", isDirectory: true),
        fileManager: FileManager = .default
    ) {
        self.root = root
        self.fileManager = fileManager
    }

    func latestSnapshot(now: Date = Date()) -> QuotaSnapshot? {
        if shouldRediscover(now: now) {
            candidates = discoverCandidates()
            lastDiscovery = now
            candidateDirectoryModificationDate = currentCandidateDirectoryModificationDate()
        } else {
            candidates = sortByModificationDate(candidates)
        }

        for url in candidates.prefix(32) {
            if let snapshot = snapshotFromTail(of: url) { return snapshot }
        }
        return nil
    }

    private func shouldRediscover(now: Date) -> Bool {
        if candidates.isEmpty || now.timeIntervalSince(lastDiscovery) >= 300 { return true }
        guard
            let previous = candidateDirectoryModificationDate,
            let current = currentCandidateDirectoryModificationDate()
        else {
            return false
        }
        return current > previous
    }

    private func currentCandidateDirectoryModificationDate() -> Date? {
        guard let directory = candidates.first?.deletingLastPathComponent() else { return nil }
        return try? directory.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    private func discoverCandidates() -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsPackageDescendants, .skipsHiddenFiles]
        ) else {
            return []
        }

        var urls: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            if (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                urls.append(url)
            }
        }
        return sortByModificationDate(urls)
    }

    private func sortByModificationDate(_ urls: [URL]) -> [URL] {
        urls.sorted {
            let lhs = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhs = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhs > rhs
        }
    }

    private func snapshotFromTail(of url: URL) -> QuotaSnapshot? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        guard let end = try? handle.seekToEnd() else { return nil }
        let start = end > UInt64(tailLimit) ? end - UInt64(tailLimit) : 0
        do {
            try handle.seek(toOffset: start)
            guard let data = try handle.readToEnd(), !data.isEmpty else { return nil }
            let lines = data.split(separator: 0x0A, omittingEmptySubsequences: true)
            for rawLine in lines.reversed() {
                let line = Data(rawLine)
                guard line.range(of: Data("\"rate_limits\"".utf8)) != nil else { continue }
                do {
                    if let snapshot = try QuotaEventParser.parse(line: line) {
                        return snapshot
                    }
                } catch {
                    continue
                }
            }
        } catch {
            return nil
        }
        return nil
    }
}
