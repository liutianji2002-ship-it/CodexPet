import Foundation

final class CodexThreadTitleResolver {
    private let stateDatabaseURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codex/state_5.sqlite", isDirectory: false)
    private let sqliteURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
    private let queue = DispatchQueue(label: "CodexPet.thread-title-resolver")
    private let recentThreadLimit = 200
    private let cacheLock = NSLock()

    private var cache: [String: String] = [:]
    private var timer: DispatchSourceTimer?

    func start() {
        queue.async { [weak self] in
            guard let self, self.timer == nil else { return }

            self.refreshCache()

            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now() + .seconds(5), repeating: .seconds(10))
            timer.setEventHandler { [weak self] in
                self?.refreshCache()
            }
            self.timer = timer
            timer.resume()
        }
    }

    func stop() {
        queue.async { [self] in
            self.timer?.cancel()
            self.timer = nil
        }
    }

    func title(forThreadId threadId: String) -> String? {
        cacheLock.lock()
        let title = cache[threadId]
        cacheLock.unlock()
        return title
    }

    private func refreshCache() {
        guard FileManager.default.fileExists(atPath: stateDatabaseURL.path) else {
            cacheLock.lock()
            cache.removeAll()
            cacheLock.unlock()
            return
        }

        let query = """
        SELECT id || char(9) || title
        FROM threads
        WHERE title IS NOT NULL
          AND title != ''
        ORDER BY updated_at DESC
        LIMIT \(recentThreadLimit);
        """

        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = sqliteURL
        process.arguments = [
            stateDatabaseURL.path,
            "-batch",
            query
        ]
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return
        }

        guard process.terminationStatus == 0 else {
            return
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let text = String(decoding: data, as: UTF8.self)
        var nextCache: [String: String] = [:]

        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }

            let threadId = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let title = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !threadId.isEmpty, !title.isEmpty else { continue }
            nextCache[threadId] = title
        }

        guard !nextCache.isEmpty else {
            return
        }

        cacheLock.lock()
        cache = nextCache
        cacheLock.unlock()
    }
}
