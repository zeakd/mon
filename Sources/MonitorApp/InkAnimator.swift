import AppKit
import Foundation
import MonitorKit

/// 세션 상태를 잉크 방울로 변환하고 프레임 애니메이션을 구동
@MainActor
final class InkAnimator: ObservableObject {
    @Published var currentImage: NSImage?

    private let renderer: InkRenderer
    private var drops: [String: InkDrop] = [:]  // session.id → drop
    private var timer: Timer?
    private var tick: Int = 0

    // 타이밍
    private let fps: TimeInterval = 1.0 / 10  // 10fps, 프레임 교체 단위
    private let runningCycleTicks = 3   // 0.3초 = 3 ticks at 10fps
    private let waitingCycleTicks = 15  // 1.5초 = 15 ticks at 10fps

    init(retina: Bool = true) {
        self.renderer = InkRenderer(retina: retina)
        startTimer()
    }

    /// 세션 목록이 바뀔 때 호출
    func updateSessions(_ sessions: [Session], idleTimeout: TimeInterval) {
        let activeIds = Set(sessions.map(\.id))

        // 사라진 세션의 drop 제거 (done 증발은 추후 구현)
        for id in drops.keys where !activeIds.contains(id) {
            drops.removeValue(forKey: id)
        }

        // 새 세션에 drop 생성
        for session in sessions {
            let isActive = session.isActive(timeout: idleTimeout)
            if var existing = drops[session.id] {
                existing.isActive = isActive
                drops[session.id] = existing
            } else {
                let drop = createDrop(for: session, isActive: isActive)
                drops[session.id] = drop
            }
        }
    }

    private func createDrop(for session: Session, isActive: Bool) -> InkDrop {
        // 무작위 위치, 기존 방울과 최소 간격
        let w = Double(renderer.width)
        let h = Double(renderer.height)
        let baseR = renderer.useRetina ? 5.0 : 3.0

        var cx: Double
        var cy: Double
        var attempts = 0
        repeat {
            cx = Double.random(in: (baseR + 2)...(w - baseR - 2))
            cy = Double.random(in: (baseR)...(h - baseR))
            attempts += 1
        } while attempts < 20 && drops.values.contains(where: { d in
            let dx = d.centerX - cx
            let dy = d.centerY - cy
            return sqrt(dx * dx + dy * dy) < baseR * 2.5
        })

        return InkDrop(
            centerX: cx, centerY: cy,
            baseRadius: baseR,
            isActive: isActive)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: fps, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.advance()
            }
        }
    }

    private func advance() {
        tick += 1

        // 각 방울의 애니메이션 상태 업데이트
        for (id, var drop) in drops {
            if drop.isActive {
                // running: breathing 주기
                let phase = Double(tick % (runningCycleTicks * 2)) / Double(runningCycleTicks * 2)
                drop.breathPhase = phase
            } else {
                // waiting: 가장자리 토글
                if tick % waitingCycleTicks == 0 {
                    drop.showEdge.toggle()
                }
            }
            drops[id] = drop
        }

        // 프레임 렌더 → 이미지
        let frame = renderer.renderFrame(drops: Array(drops.values))
        currentImage = renderer.frameToImage(frame)
    }
}
