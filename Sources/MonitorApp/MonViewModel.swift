import Foundation
import MonitorKit
import Combine

@MainActor
final class MonViewModel: ObservableObject {
    @Published var sessions: [Session] = []

    private var timer: Timer?
    private let store: SessionStore?
    private let pollInterval: TimeInterval = 3
    private let settings = AnimationSettings.shared

    var idleTimeout: TimeInterval { settings.idleTimeout }

    init() {
        self.store = try? SessionStore()
        startPolling()
    }

    var activeSessions: [Session] {
        sessions.filter { $0.isActive(timeout: idleTimeout) }
    }

    var idleSessions: [Session] {
        sessions.filter { !$0.isActive(timeout: idleTimeout) }
    }

    var activeCount: Int { activeSessions.count }

    private func startPolling() {
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.poll()
            }
        }
    }

    private func poll() {
        guard let store else { return }
        do {
            sessions = try store.list()
        } catch {}
    }
}
