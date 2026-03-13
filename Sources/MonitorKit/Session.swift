import Foundation

public struct Session: Sendable, Identifiable, Equatable {
    public let id: String
    public var title: String
    public let machine: String
    public let startedAt: Date
    public var updatedAt: Date

    public init(id: String = UUID().uuidString, title: String, machine: String = ProcessInfo.processInfo.hostName, startedAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.machine = machine
        self.startedAt = startedAt
        self.updatedAt = updatedAt
    }

    /// heartbeat 기반 active 판정
    public func isActive(timeout: TimeInterval = 30) -> Bool {
        Date().timeIntervalSince(updatedAt) < timeout
    }
}
