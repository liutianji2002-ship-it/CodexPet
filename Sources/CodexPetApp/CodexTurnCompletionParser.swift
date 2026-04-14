import Foundation

struct CodexTurnCompletionParser {
    private let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private let fallbackFormatter = ISO8601DateFormatter()
    private let regex = try! NSRegularExpression(
        pattern: #"show turn-complete conversationId=([0-9a-fA-F-]+) turnId=([0-9a-fA-F-]+)"#,
        options: []
    )

    func parse(line: String) -> CodexTurnCompletionEvent? {
        let fullRange = NSRange(line.startIndex..., in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: fullRange) else {
            return nil
        }

        guard
            let conversationRange = Range(match.range(at: 1), in: line),
            let turnRange = Range(match.range(at: 2), in: line)
        else {
            return nil
        }

        let timestampToken = line.split(separator: " ", maxSplits: 1).first.map(String.init) ?? ""
        let timestamp = formatter.date(from: timestampToken) ?? fallbackFormatter.date(from: timestampToken) ?? .now

        return CodexTurnCompletionEvent(
            timestamp: timestamp,
            conversationId: String(line[conversationRange]),
            turnId: String(line[turnRange]),
            source: .logTail,
            rawLine: line
        )
    }
}
