import Foundation

struct CodexLogLocator {
    private let fileManager = FileManager.default
    private let calendar = Calendar(identifier: .gregorian)
    let rootDirectory: URL

    init(rootDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/com.openai.codex", isDirectory: true)
    ) {
        self.rootDirectory = rootDirectory
    }

    func newestLogFile(referenceDate: Date = .now) -> URL? {
        let candidateDirectories = [0, -1].map { offset in
            calendar.date(byAdding: .day, value: offset, to: referenceDate) ?? referenceDate
        }.map(dayDirectory(for:))

        let candidateFiles = candidateDirectories
            .filter { fileManager.fileExists(atPath: $0.path) }
            .flatMap(logFiles(in:))

        if let newest = newestByModificationDate(candidateFiles) {
            return newest
        }

        return newestByModificationDate(logFiles(in: rootDirectory))
    }

    private func dayDirectory(for date: Date) -> URL {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return rootDirectory
            .appendingPathComponent(String(format: "%04d", year), isDirectory: true)
            .appendingPathComponent(String(format: "%02d", month), isDirectory: true)
            .appendingPathComponent(String(format: "%02d", day), isDirectory: true)
    }

    private func logFiles(in directory: URL) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return enumerator.compactMap { item in
            guard let fileURL = item as? URL, fileURL.pathExtension == "log" else {
                return nil
            }

            let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
            return values?.isRegularFile == true ? fileURL : nil
        }
    }

    private func newestByModificationDate(_ files: [URL]) -> URL? {
        files.max { lhs, rhs in
            modificationDate(of: lhs) < modificationDate(of: rhs)
        }
    }

    private func modificationDate(of file: URL) -> Date {
        let values = try? file.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate ?? .distantPast
    }
}
