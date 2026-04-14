import Foundation

final class CodexTurnCompletionMonitor {
    var onEvent: ((CodexTurnCompletionEvent) -> Void)?
    var onStatusChange: ((String) -> Void)?

    private let queue = DispatchQueue(label: "CodexPet.turn-monitor")
    private let locator = CodexLogLocator()
    private let parser = CodexTurnCompletionParser()

    private var timer: DispatchSourceTimer?
    private var activeFile: URL?
    private var fileHandle: FileHandle?
    private var fileOffset: UInt64 = 0
    private var lineRemainder = ""
    private var seenTurnIds = Set<String>()
    private var turnIdOrder: [String] = []

    func start() {
        queue.async { [weak self] in
            guard let self, self.timer == nil else { return }

            self.switchToLatestFile(skipExistingContent: true)
            self.publishStatus()

            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now() + .seconds(1), repeating: .seconds(1))
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
            self.closeActiveFile()
        }
    }

    private func poll() {
        switchToLatestFile(skipExistingContent: false)
        readNewContent()
    }

    private func switchToLatestFile(skipExistingContent: Bool) {
        guard let latestFile = locator.newestLogFile() else {
            if activeFile != nil {
                closeActiveFile()
                publishStatus()
            }
            return
        }

        guard latestFile != activeFile else { return }

        closeActiveFile()

        do {
            let handle = try FileHandle(forReadingFrom: latestFile)
            let fileSize = handle.seekToEndOfFile()

            if skipExistingContent {
                fileOffset = fileSize
            } else {
                handle.seek(toFileOffset: 0)
                fileOffset = 0
            }

            activeFile = latestFile
            fileHandle = handle
            lineRemainder = ""
            publishStatus()
        } catch {
            closeActiveFile()
            publishStatus(message: "Cannot open \(latestFile.lastPathComponent)")
        }
    }

    private func readNewContent() {
        guard let fileHandle else { return }

        let fileSize = fileHandle.seekToEndOfFile()
        if fileSize < fileOffset {
            fileOffset = 0
            lineRemainder = ""
        }

        guard fileSize > fileOffset else { return }

        fileHandle.seek(toFileOffset: fileOffset)
        let data = fileHandle.readDataToEndOfFile()
        fileOffset += UInt64(data.count)

        guard !data.isEmpty else { return }
        processChunk(String(decoding: data, as: UTF8.self))
    }

    private func processChunk(_ chunk: String) {
        let combined = lineRemainder + chunk
        let lines = combined.split(separator: "\n", omittingEmptySubsequences: false)

        let completeLines: ArraySlice<Substring>
        if combined.hasSuffix("\n") {
            lineRemainder = ""
            completeLines = lines[...]
        } else {
            lineRemainder = lines.last.map(String.init) ?? ""
            completeLines = lines.dropLast()
        }

        for rawLine in completeLines {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, let event = parser.parse(line: line) else {
                continue
            }
            publish(event)
        }
    }

    private func publish(_ event: CodexTurnCompletionEvent) {
        guard seenTurnIds.insert(event.turnId).inserted else { return }

        turnIdOrder.append(event.turnId)
        while turnIdOrder.count > 100 {
            let removed = turnIdOrder.removeFirst()
            seenTurnIds.remove(removed)
        }

        onEvent?(event)
    }

    private func publishStatus(message: String? = nil) {
        if let message {
            onStatusChange?(message)
        } else if let activeFile {
            onStatusChange?("Watching \(activeFile.lastPathComponent)")
        } else {
            onStatusChange?("No Codex log file found")
        }
    }

    private func closeActiveFile() {
        fileHandle?.closeFile()
        fileHandle = nil
        activeFile = nil
        fileOffset = 0
        lineRemainder = ""
    }
}
