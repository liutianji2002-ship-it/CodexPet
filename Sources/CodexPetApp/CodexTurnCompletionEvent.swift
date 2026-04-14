import Foundation

struct CodexTurnCompletionEvent: Equatable, Sendable {
    let timestamp: Date
    let conversationId: String
    let turnId: String
    let source: CodexEventSource
    let rawLine: String
}
