import Foundation

public struct Session: Sendable, Identifiable, Equatable {
    public let id: String
    public var title: String
    public let machine: String
    public let startedAt: Date
    public var updatedAt: Date
    public var focusCommand: String?  // 클릭 시 실행할 셸 커맨드 (호출측이 주입)

    public init(id: String = UUID().uuidString, title: String, machine: String = ProcessInfo.processInfo.hostName, startedAt: Date = Date(), updatedAt: Date = Date(), focusCommand: String? = nil) {
        self.id = id
        self.title = title
        self.machine = machine
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.focusCommand = focusCommand
    }

    /// heartbeat 기반 active 판정
    public func isActive(timeout: TimeInterval = 30) -> Bool {
        Date().timeIntervalSince(updatedAt) < timeout
    }

    /// focusCommand가 있으면 true
    public var canFocus: Bool { focusCommand != nil }
}
