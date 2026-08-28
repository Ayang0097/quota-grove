import Foundation

final class LocalRateLimitSource {
    private static let searchChunkSize = 256 * 1_024
    private static let incrementalSearchLimit = 16 * 1_024 * 1_024

    private let root: URL
    private let fileManager: FileManager
    private var candidates: [URL] = []
    private var snapshotsByFile: [URL: QuotaSnapshot] = [:]
    private var lastDiscovery = Date.distantPast
    private var candidateDirectoryModificationDate: Date?

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

        var newestSnapshot: QuotaSnapshot?
        for url in candidates.prefix(32) {
            let modificationDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                ?? .distantPast
            if let newestSnapshot, modificationDate <= newestSnapshot.fetchedAt { break }

            let cachedSnapshot = snapshotsByFile[url]
            let searchLimit = cachedSnapshot == nil ? nil : Self.incrementalSearchLimit
            let scannedSnapshot = snapshotFromEnd(of: url, maximumBytes: searchLimit)
            let fileSnapshot = newer(scannedSnapshot, cachedSnapshot)
            if let fileSnapshot {
                snapshotsByFile[url] = fileSnapshot
                newestSnapshot = newer(newestSnapshot, fileSnapshot)
            }
        }
        return newestSnapshot
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

    private func snapshotFromEnd(of url: URL, maximumBytes: Int?) -> QuotaSnapshot? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        guard let end = try? handle.seekToEnd() else { return nil }
        let minimumOffset: UInt64
        if let maximumBytes, end > UInt64(maximumBytes) {
            minimumOffset = end - UInt64(maximumBytes)
        } else {
            minimumOffset = 0
        }

        var cursor = end
        var suffix = Data()
        do {
            while cursor > minimumOffset {
                let chunkSize = UInt64(Self.searchChunkSize)
                let start = max(minimumOffset, cursor > chunkSize ? cursor - chunkSize : 0)
                let beginsAtLineBoundary: Bool
                if start == 0 {
                    beginsAtLineBoundary = true
                } else {
                    try handle.seek(toOffset: start - 1)
                    beginsAtLineBoundary = try handle.read(upToCount: 1)?.first == 0x0A
                }

                try handle.seek(toOffset: start)
                guard var data = try handle.read(upToCount: Int(cursor - start)) else { break }
                data.append(suffix)
                let lines = data.split(separator: 0x0A, omittingEmptySubsequences: false)
                let firstCompleteLine = beginsAtLineBoundary ? 0 : 1
                if lines.count > firstCompleteLine {
                    for index in stride(from: lines.count - 1, through: firstCompleteLine, by: -1) {
                        let line = Data(lines[index])
                        guard !line.isEmpty, line.range(of: Data("\"rate_limits\"".utf8)) != nil else { continue }
                        do {
                            if let snapshot = try QuotaEventParser.parse(line: line) {
                                return snapshot
                            }
                        } catch {
                            continue
                        }
                    }
                }

                suffix = beginsAtLineBoundary ? Data() : lines.first.map { Data($0) } ?? Data()
                cursor = start
            }
        } catch {
            return nil
        }
        return nil
    }

    private func newer(_ lhs: QuotaSnapshot?, _ rhs: QuotaSnapshot?) -> QuotaSnapshot? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?): return lhs.fetchedAt >= rhs.fetchedAt ? lhs : rhs
        case let (lhs?, nil): return lhs
        case let (nil, rhs?): return rhs
        case (nil, nil): return nil
        }
    }
}
