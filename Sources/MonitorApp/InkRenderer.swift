import AppKit
import Foundation

/// 잉크 방울 하나의 상태
struct InkDrop {
    var centerX: Double
    var centerY: Double
    var baseRadius: Double
    var isActive: Bool

    /// 개별 phase offset — 방울마다 다른 리듬
    var phaseOffset: Double

    /// breathing phase (0.0 ~ 1.0)
    var breathPhase: Double = 0

    /// blink state — idle 전용
    var showEdge: Bool = true

    /// 드리프트 — 방울이 천천히 떠다님
    var driftAngle: Double
    var driftSpeed: Double

    /// 유기적 형태를 위한 noise seed
    var noiseSeed: Double
}

/// 픽셀 잉크 프레임을 생성하고 NSImage로 변환
final class InkRenderer {
    let useRetina: Bool
    let width: Int
    let height: Int
    let maxLevel: Int

    init(retina: Bool = true) {
        self.useRetina = retina
        self.width = retina ? 72 : 36
        self.height = retina ? 20 : 10
        self.maxLevel = retina ? 4 : 3
    }

    func renderFrame(drops: [InkDrop]) -> [[Int]] {
        var canvas = Array(repeating: Array(repeating: 0, count: width), count: height)

        for drop in drops {
            let r = currentRadius(for: drop)
            renderDrop(on: &canvas, drop: drop, radius: r)
        }

        return canvas
    }

    func frameToImage(_ frame: [[Int]]) -> NSImage {
        let scale = useRetina ? 2 : 1
        let ptW = width / scale
        let ptH = height / scale

        let image = NSImage(size: NSSize(width: ptW, height: ptH))
        image.lockFocus()

        let ctx = NSGraphicsContext.current!.cgContext

        let alphas: [CGFloat] = useRetina
            ? [0, 0.15, 0.35, 0.65, 1.0]
            : [0, 0.25, 0.6, 1.0]

        let pixelSize = 1.0 / CGFloat(scale)

        for y in 0..<height {
            for x in 0..<width {
                let level = frame[y][x]
                guard level > 0 else { continue }
                let alpha = alphas[min(level, alphas.count - 1)]
                ctx.setFillColor(CGColor(gray: 0, alpha: alpha))
                ctx.fill(CGRect(
                    x: CGFloat(x) * pixelSize,
                    y: CGFloat(height - 1 - y) * pixelSize,
                    width: pixelSize,
                    height: pixelSize))
            }
        }

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    // MARK: - Internal

    private func currentRadius(for drop: InkDrop) -> Double {
        if drop.isActive {
            let breath = sin(drop.breathPhase * .pi * 2)
            let amp = AnimationSettings.shared.breathAmplitude
            return drop.baseRadius * (1.0 + amp * breath)
        } else {
            return drop.baseRadius * 0.85
        }
    }

    private func renderDrop(on canvas: inout [[Int]], drop: InkDrop, radius r: Double) {
        let cx = drop.centerX
        let cy = drop.centerY

        // 바운딩 박스로 범위 제한
        let minX = max(0, Int(cx - r - 2))
        let maxX = min(width - 1, Int(cx + r + 2))
        let minY = max(0, Int(cy - r - 2))
        let maxY = min(height - 1, Int(cy + r + 2))

        for y in minY...maxY {
            for x in minX...maxX {
                let dx = Double(x) - cx
                let dy = Double(y) - cy
                let d = sqrt(dx * dx + dy * dy)

                // 유기적 윤곽: 각도에 따라 반경이 울퉁불퉁
                let angle = atan2(dy, dx)
                let noise = organicNoise(angle: angle, seed: drop.noiseSeed, phase: drop.breathPhase)
                let effectiveR = r * (1.0 + 0.25 * noise)

                guard d < effectiveR else { continue }

                // 정규화된 거리 (0 = 중심, 1 = 가장자리)
                let normalD = d / effectiveR

                let level: Int
                if useRetina {
                    if normalD < 0.25 { level = 4 }
                    else if normalD < 0.50 { level = 3 }
                    else if normalD < 0.75 { level = 2 }
                    else { level = 1 }
                } else {
                    if normalD < 0.3 { level = 3 }
                    else if normalD < 0.6 { level = 2 }
                    else { level = 1 }
                }

                if !drop.isActive && !drop.showEdge && level <= 1 {
                    continue
                }

                canvas[y][x] = min(canvas[y][x] + level, maxLevel)
            }
        }
    }

    /// 각도 기반 유기적 노이즈 — 잉크 번짐 윤곽
    private func organicNoise(angle: Double, seed: Double, phase: Double) -> Double {
        // 3개 주파수의 사인파 중첩으로 불규칙 윤곽 생성
        let a1 = sin(angle * 2 + seed) * 0.4
        let a2 = sin(angle * 3 + seed * 1.7 + phase * .pi) * 0.3
        let a3 = sin(angle * 5 + seed * 2.3) * 0.2
        return a1 + a2 + a3
    }
}
