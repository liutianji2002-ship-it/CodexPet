import Foundation

final class CodexAppServerMonitor: NSObject, URLSessionWebSocketDelegate {
    var onEvent: ((CodexTurnCompletionEvent) -> Void)?
    var onStatusChange: ((String) -> Void)?
    var onActiveThreadCountChange: ((Int) -> Void)?

    private enum PendingRequest {
        case initialize
        case threadList
    }

    private struct ThreadSnapshot {
        let statusType: String
    }

    private let serverURL = URL(string: "ws://127.0.0.1:7898")!
    private let queue = DispatchQueue(label: "CodexPet.direct-monitor")
    private let threadDisplayTextsLock = NSLock()

    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    private var webSocketTask: URLSessionWebSocketTask?
    private var pollTimer: DispatchSourceTimer?
    private var reconnectWorkItem: DispatchWorkItem?
    private var pendingRequests: [Int: PendingRequest] = [:]
    private var nextRequestID = 1
    private var deliveredTurnIds = Set<String>()
    private var deliveredTurnOrder: [String] = []
    private var threadSnapshots: [String: ThreadSnapshot] = [:]
    private var threadDisplayTexts: [String: String] = [:]
    private var runningThreadIDs = Set<String>()
    private var lastActiveThreadCount: Int?
    private var handshakeCompleted = false
    private var bootstrapCompleted = false
    private var isStopped = false

    func start() {
        queue.async { [weak self] in
            guard let self else { return }
            self.isStopped = false
            self.connect()
        }
    }

    func stop() {
        queue.async { [self] in
            self.isStopped = true
            self.reconnectWorkItem?.cancel()
            self.reconnectWorkItem = nil
            self.stopPolling()
            self.pendingRequests.removeAll()
            self.threadDisplayTextsLock.lock()
            self.threadDisplayTexts.removeAll()
            self.threadDisplayTextsLock.unlock()
            self.threadSnapshots.removeAll()
            self.runningThreadIDs.removeAll()
            self.lastActiveThreadCount = nil
            self.webSocketTask?.cancel(with: .goingAway, reason: nil)
            self.webSocketTask = nil
            self.session.invalidateAndCancel()
        }
    }

    func displayText(forThreadId threadId: String) -> String? {
        threadDisplayTextsLock.lock()
        let displayText = threadDisplayTexts[threadId]
        threadDisplayTextsLock.unlock()
        return displayText
    }

    func matchesDisplayText(forThreadId threadId: String, against candidate: String?) -> Bool {
        let displayText = displayText(forThreadId: threadId)
        return normalizedDisplayText(displayText).isEmpty == false
            && normalizedDisplayText(displayText) == normalizedDisplayText(candidate)
    }

    private func connect() {
        guard !isStopped, webSocketTask == nil else { return }

        publishStatus("Connecting direct WS")

        let task = session.webSocketTask(with: serverURL)
        webSocketTask = task
        handshakeCompleted = false
        bootstrapCompleted = false
        task.resume()
        receiveNextMessage()
    }

    private func receiveNextMessage() {
        guard let webSocketTask else { return }

        webSocketTask.receive { [weak self] result in
            guard let self else { return }
            self.queue.async {
                switch result {
                case .success(let message):
                    self.handle(message)
                    self.receiveNextMessage()
                case .failure(let error):
                    self.publishStatus("Direct WS receive failed")
                    self.scheduleReconnect(reason: error.localizedDescription)
                }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        let payload: Data

        switch message {
        case .string(let string):
            payload = Data(string.utf8)
        case .data(let data):
            payload = data
        @unknown default:
            return
        }

        guard
            let object = try? JSONSerialization.jsonObject(with: payload),
            let dictionary = object as? [String: Any]
        else {
            return
        }

        if let method = dictionary["method"] as? String {
            handleNotification(method: method, payload: dictionary)
            return
        }

        if let id = requestID(from: dictionary) {
            handleResponse(id: id, payload: dictionary)
        }
    }

    private func handleNotification(method: String, payload: [String: Any]) {
        switch method {
        case "turn/completed":
            guard bootstrapCompleted else {
                return
            }

            guard
                let params = payload["params"] as? [String: Any],
                let threadId = params["threadId"] as? String,
                let turn = params["turn"] as? [String: Any],
                let turnId = turn["id"] as? String
            else {
                return
            }

            threadSnapshots[threadId] = ThreadSnapshot(statusType: "completed")
            runningThreadIDs.remove(threadId)
            publishActiveThreadCountIfNeeded()

            publish(
                CodexTurnCompletionEvent(
                    timestamp: .now,
                    conversationId: threadId,
                    turnId: turnId,
                    source: .directAppServer,
                    rawLine: "turn/completed"
                )
            )

        case "turn/started":
            guard
                let params = payload["params"] as? [String: Any],
                let threadId = params["threadId"] as? String
            else {
                return
            }

            threadSnapshots[threadId] = ThreadSnapshot(statusType: "inProgress")
            runningThreadIDs.insert(threadId)
            publishActiveThreadCountIfNeeded()

        case "thread/status/changed":
            guard
                let params = payload["params"] as? [String: Any],
                let threadId = params["threadId"] as? String,
                let status = params["status"] as? [String: Any],
                let type = status["type"] as? String
            else {
                return
            }

            threadSnapshots[threadId] = ThreadSnapshot(statusType: type)
            if type == "active" {
                runningThreadIDs.insert(threadId)
            } else {
                runningThreadIDs.remove(threadId)
            }
            publishActiveThreadCountIfNeeded()

        default:
            break
        }
    }

    private func handleResponse(id: Int, payload: [String: Any]) {
        guard let pending = pendingRequests.removeValue(forKey: id) else {
            return
        }

        if payload["error"] != nil {
            if case .initialize = pending {
                publishStatus("Direct WS initialize failed")
                scheduleReconnect(reason: "initialize failed")
            }
            return
        }

        switch pending {
        case .initialize:
            handshakeCompleted = true
            publishStatus("Direct WS connected")
            sendNotification(method: "initialized")
            startPolling()

        case .threadList:
            guard
                let result = payload["result"] as? [String: Any],
                let data = result["data"] as? [[String: Any]]
            else {
                return
            }
            processThreadList(data)
            publishActiveThreadCountIfNeeded()
            if !bootstrapCompleted {
                bootstrapCompleted = true
                publishStatus("Direct WS live")
            }
        }
    }

    private func processThreadList(_ threads: [[String: Any]]) {
        var visibleThreadIDs = Set<String>()

        for thread in threads {
            guard
                let threadId = thread["id"] as? String,
                let status = thread["status"] as? [String: Any],
                let statusType = status["type"] as? String
            else {
                continue
            }

            visibleThreadIDs.insert(threadId)
            threadSnapshots[threadId] = ThreadSnapshot(statusType: statusType)
            if let displayText = displayText(from: thread) {
                threadDisplayTextsLock.lock()
                threadDisplayTexts[threadId] = displayText
                threadDisplayTextsLock.unlock()
            }

            if statusType == "active" {
                runningThreadIDs.insert(threadId)
            }
        }

        runningThreadIDs = runningThreadIDs.filter { threadId in
            guard let snapshot = threadSnapshots[threadId] else {
                return false
            }
            return snapshot.statusType == "active" || snapshot.statusType == "inProgress"
        }
        threadSnapshots = threadSnapshots.filter { visibleThreadIDs.contains($0.key) }
        threadDisplayTextsLock.lock()
        threadDisplayTexts = threadDisplayTexts.filter { visibleThreadIDs.contains($0.key) }
        threadDisplayTextsLock.unlock()
    }

    private func startPolling() {
        guard pollTimer == nil else { return }

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + .seconds(2), repeating: .seconds(4))
        timer.setEventHandler { [weak self] in
            self?.requestThreadList()
        }
        pollTimer = timer
        timer.resume()
        requestThreadList()
    }

    private func stopPolling() {
        pollTimer?.cancel()
        pollTimer = nil
    }

    private func requestThreadList() {
        guard handshakeCompleted else { return }

        sendRequest(
            method: "thread/list",
            params: [
                "limit": 50,
                "cursor": NSNull(),
                "sortKey": "updated_at",
                "modelProviders": NSNull(),
                "archived": false,
                "sourceKinds": NSNull()
            ],
            kind: .threadList
        )
    }

    private func sendInitialize() {
        sendRequest(
            method: "initialize",
            params: [
                "clientInfo": [
                    "name": "CodexPet",
                    "version": "0.1.0"
                ],
                "capabilities": NSNull()
            ],
            kind: .initialize
        )
    }

    private func sendNotification(method: String, params: Any? = nil) {
        var payload: [String: Any] = ["method": method]
        if let params {
            payload["params"] = params
        }
        send(payload)
    }

    private func sendRequest(method: String, params: Any, kind: PendingRequest) {
        let id = nextRequestID
        nextRequestID += 1
        pendingRequests[id] = kind

        send([
            "id": id,
            "method": method,
            "params": params
        ])
    }

    private func send(_ payload: [String: Any]) {
        guard let webSocketTask else { return }
        guard
            let data = try? JSONSerialization.data(withJSONObject: payload),
            let string = String(data: data, encoding: .utf8)
        else {
            return
        }

        webSocketTask.send(.string(string)) { [weak self] error in
            guard let self, let error else { return }
            self.queue.async {
                self.publishStatus("Direct WS send failed")
                self.scheduleReconnect(reason: error.localizedDescription)
            }
        }
    }

    private func requestID(from payload: [String: Any]) -> Int? {
        if let intID = payload["id"] as? Int {
            return intID
        }
        if let stringID = payload["id"] as? String {
            return Int(stringID)
        }
        if let number = payload["id"] as? NSNumber {
            return number.intValue
        }
        return nil
    }

    private func displayText(from thread: [String: Any]) -> String? {
        let candidates = [
            thread["name"] as? String,
            thread["preview"] as? String
        ]

        for candidate in candidates {
            let text = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !text.isEmpty {
                return text
            }
        }

        return nil
    }

    private func normalizedDisplayText(_ text: String?) -> String {
        guard let text else {
            return ""
        }

        return text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func publish(_ event: CodexTurnCompletionEvent) {
        guard deliveredTurnIds.insert(event.turnId).inserted else { return }

        deliveredTurnOrder.append(event.turnId)
        while deliveredTurnOrder.count > 200 {
            let removed = deliveredTurnOrder.removeFirst()
            deliveredTurnIds.remove(removed)
        }

        onEvent?(event)
    }

    private func publishStatus(_ status: String) {
        onStatusChange?(status)
    }

    private func publishActiveThreadCountIfNeeded() {
        let activeCount = runningThreadIDs.count

        guard activeCount != lastActiveThreadCount else {
            return
        }

        lastActiveThreadCount = activeCount
        onActiveThreadCountChange?(activeCount)
    }

    private func scheduleReconnect(reason: String) {
        guard !isStopped else { return }
        guard reconnectWorkItem == nil else { return }

        stopPolling()
        pendingRequests.removeAll()
        runningThreadIDs.removeAll()
        lastActiveThreadCount = nil
        publishActiveThreadCountIfNeeded()
        handshakeCompleted = false
        bootstrapCompleted = false
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.reconnectWorkItem = nil
            self.publishStatus("Retrying direct WS")
            self.connect()
        }

        reconnectWorkItem = workItem
        publishStatus("Direct WS unavailable")
        queue.asyncAfter(deadline: .now() + .seconds(2), execute: workItem)
        _ = reason
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        queue.async { [weak self] in
            self?.publishStatus("Direct WS handshake")
            self?.sendInitialize()
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        queue.async { [weak self] in
            self?.scheduleReconnect(reason: "closed \(closeCode.rawValue)")
        }
    }
}
