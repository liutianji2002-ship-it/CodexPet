import Foundation

final class CodexRuntimeActivityMonitor {
    var onActiveThreadCountChange: ((Int) -> Void)?

    private let queue = DispatchQueue(label: "CodexPet.runtime-activity-monitor")
    private let fileManager = FileManager.default
    private let stateDatabaseURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codex/state_5.sqlite", isDirectory: false)
    private let sqliteURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
    private let recentThreadLimit = 80
    private let tailReadBytes = 1024 * 1024
    private let lowerCountDebounceSeconds: TimeInterval = 2
    private let activeStartTypes: Set<String> = ["task_started"]
    private let terminalTypes: Set<String> = [
        "task_complete",
        "turn_aborted",
        "task_failed",
        "turn_failed"
    ]

    private var timer: DispatchSourceTimer?
    private var lastCount: Int?
    private var isPolling = false
    private var pendingCount: Int?
    private var pendingCountObservedAt: Date?

    func start() {
        queue.async { [weak self] in
            guard let self, self.timer == nil else { return }

            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now(), repeating: .seconds(2))
            timer.setEventHandler { [weak self] in
                self?.poll()
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

    private func poll() {
        guard !isPolling else { return }
        isPolling = true

        let count = activeThreadCount()
        finishPoll(with: count)
    }

    private func activeThreadCount() -> Int {
        guard fileManager.fileExists(atPath: stateDatabaseURL.path) else {
            return 0
        }

        let sessionPaths = recentSessionPaths()
        guard !sessionPaths.isEmpty else {
            return 0
        }

        return sessionPaths.reduce(into: 0) { count, path in
            if isThreadActive(at: path) {
                count += 1
            }
        }
    }

    private func recentSessionPaths() -> [String] {
        let query = """
        SELECT rollout_path
        FROM threads
        WHERE rollout_path IS NOT NULL
          AND rollout_path != ''
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
            return []
        }

        guard process.terminationStatus == 0 else {
            return []
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let text = String(decoding: data, as: UTF8.self)

        return text
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private func isThreadActive(at path: String) -> Bool {
        guard fileManager.fileExists(atPath: path) else {
            return false
        }

        guard let tailText = readTail(of: path) else {
            return false
        }

        var isActive = false

        for line in tailText.split(whereSeparator: \.isNewline) {
            guard
                let data = line.data(using: .utf8),
                let rawObject = try? JSONSerialization.jsonObject(with: data),
                let object = rawObject as? [String: Any]
            else {
                continue
            }

            if let eventType = payloadType(in: object) {
                if activeStartTypes.contains(eventType) {
                    isActive = true
                } else if terminalTypes.contains(eventType) {
                    isActive = false
                }
            }
        }

        return isActive
    }

    private func payloadType(in object: [String: Any]) -> String? {
        guard let kind = object["type"] as? String else {
            return nil
        }

        if kind == "event_msg" {
            return (object["payload"] as? [String: Any])?["type"] as? String
        }

        return nil
    }

    private func readTail(of path: String) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: path)) else {
            return nil
        }

        defer {
            try? handle.close()
        }

        let fileSize = (try? handle.seekToEnd()) ?? 0
        let readOffset = fileSize > UInt64(tailReadBytes) ? fileSize - UInt64(tailReadBytes) : 0

        do {
            try handle.seek(toOffset: readOffset)
            let data = handle.readDataToEndOfFile()
            guard !data.isEmpty else { return nil }

            var text = String(decoding: data, as: UTF8.self)
            if readOffset > 0, let firstNewlineIndex = text.firstIndex(of: "\n") {
                text = String(text[text.index(after: firstNewlineIndex)...])
            }
            return text
        } catch {
            return nil
        }
    }

    private func finishPoll(with count: Int) {
        isPolling = false

        guard let lastCount else {
            publish(count)
            return
        }

        guard count != lastCount else {
            clearPendingCount()
            return
        }

        if count > lastCount {
            publish(count)
            return
        }

        if pendingCount != count {
            pendingCount = count
            pendingCountObservedAt = .now
            return
        }

        let debounceSeconds = lowerCountDebounceSeconds
        let observedDuration = Date().timeIntervalSince(pendingCountObservedAt ?? .now)
        guard observedDuration >= debounceSeconds else {
            return
        }

        publish(count)
    }

    private func publish(_ count: Int) {
        clearPendingCount()
        guard lastCount != count else { return }
        lastCount = count
        onActiveThreadCountChange?(count)
    }

    private func clearPendingCount() {
        pendingCount = nil
        pendingCountObservedAt = nil
    }
}
