import Foundation

enum CodexEventSource: String, Equatable, Sendable {
    case directAppServer = "Direct WS"
    case logTail = "Log Tail"
}
