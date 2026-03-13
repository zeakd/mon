import AppKit
import Foundation
import MonitorKit

@MainActor
final class InkAnimator: ObservableObject {
    @Published var currentImage: NSImage?

    private let renderer: InkRenderer
    private let settings = AnimationSettings.shared
    private var drops: [String: InkDrop] = [:]
    private var timer: Timer?
    private var tick: Int = 0

    private let fps: TimeInterval = 1.0 / 10

    init(retina: Bool = true) {
        self.renderer = InkRenderer(retina: retina)
        startTimer()
    }

    func updateSessions(_ sessions: [Session], idleTimeout: TimeInterval) {
        let activeIds = Set(sessions.map(\.id))

        for id in drops.keys where !activeIds.contains(id) {
            drops.removeValue(forKey: id)
        }

        for session in sessions {
            let isActive = session.isActive(timeout: idleTimeout)
            if var existing = drops[session.id] {
                existing.isActive = isActive
                drops[session.id] = existing
            } else {
                drops[session.id] = createDrop(for: session, isActive: isActive)
            }
        }
    }

    private func createDrop(for session: Session, isActive: Bool) -> InkDrop {
        let w = Double(renderer.width)
        let h = Double(renderer.height)
        let baseR = renderer.useRetina ? 5.0 : 3.0
        let driftRange = settings.driftRange

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
            return sqrt(dx * dx + dy * dy) < baseR * 3
        })

        return InkDrop(
            centerX: cx,
            centerY: cy,
            baseRadius: baseR,
            isActive: isActive,
            phaseOffset: Double.random(in: 0...1),
            driftAngle: Double.random(in: 0...(.pi * 2)),
            driftSpeed: Double.random(in: driftRange),
            noiseSeed: Double.random(in: 0...100)
        )
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
        let w = Double(renderer.width)
        let h = Double(renderer.height)
        let cycleTicks = settings.runningCycleTicks
        let waitTicks = settings.waitingCycleTicks
        let grow = settings.actualGrowRate

        for (id, var drop) in drops {
            if drop.isActive {
                let rawPhase = Double(tick) / Double(cycleTicks) + drop.phaseOffset * Double(cycleTicks)
                drop.breathPhase = rawPhase.truncatingRemainder(dividingBy: 1.0)

                drop.centerX += cos(drop.driftAngle) * drop.driftSpeed
                drop.centerY += sin(drop.driftAngle) * drop.driftSpeed * 0.5

                let margin = drop.baseRadius + 1
                if drop.centerX < margin || drop.centerX > w - margin {
                    drop.driftAngle = .pi - drop.driftAngle
                    drop.centerX = max(margin, min(w - margin, drop.centerX))
                }
                if drop.centerY < margin || drop.centerY > h - margin {
                    drop.driftAngle = -drop.driftAngle
                    drop.centerY = max(margin, min(h - margin, drop.centerY))
                }

                if tick % 40 == 0 {
                    drop.driftAngle += Double.random(in: -0.2...0.2)
                }

                let maxR = (renderer.useRetina ? 5.0 : 3.0) * 2.0
                drop.baseRadius = min(drop.baseRadius + grow, maxR)

            } else {
                if tick % waitTicks == 0 {
                    drop.showEdge.toggle()
                }
                drop.centerX += cos(drop.driftAngle) * drop.driftSpeed * 0.2
                drop.centerY += sin(drop.driftAngle) * drop.driftSpeed * 0.1
            }

            drop.noiseSeed += 0.01
            drops[id] = drop
        }

        let frame = renderer.renderFrame(drops: Array(drops.values))
        currentImage = renderer.frameToImage(frame)
    }
}
