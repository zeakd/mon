import AppKit
import Foundation

/// 잉크 방울 하나의 상태
struct InkDrop {
    let centerX: Double
    let centerY: Double
    var baseRadius: Double
    var isActive: Bool  // true=running(breathing), false=idle(blinking)

    /// breathing phase (0.0 ~ 1.0) — running 전용
    var breathPhase: Double = 0

    /// blink state — idle 전용
    var showEdge: Bool = true
}

/// 픽셀 잉크 프레임을 생성하고 NSImage로 변환
final class InkRenderer {
    // 1x: 10h × 36w, levels 0-3
    // 2x: 20h × 72w, levels 0-4
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

    /// 모든 방울을 합성하여 하나의 프레임 생성
    func renderFrame(drops: [InkDrop]) -> [[Int]] {
        var canvas = Array(repeating: Array(repeating: 0, count: width), count: height)

        for drop in drops {
            let r = currentRadius(for: drop)
            renderDrop(on: &canvas, drop: drop, radius: r)
        }

        return canvas
    }

    /// 프레임을 NSImage (template) 로 변환
    func frameToImage(_ frame: [[Int]]) -> NSImage {
        let scale = useRetina ? 2 : 1
        let ptW = width / scale
        let ptH = height / scale

        let image = NSImage(size: NSSize(width: ptW, height: ptH))
        image.lockFocus()

        let ctx = NSGraphicsContext.current!.cgContext

        // 밀도별 알파값
        let alphas: [CGFloat] = useRetina
            ? [0, 0.2, 0.4, 0.7, 1.0]   // 2x: 5단계 (0=빈, 1=░, 2=▒, 3=▓, 4=█)
            : [0, 0.3, 0.7, 1.0]          // 1x: 4단계 (0=빈, 1=░, 2=▓, 3=█)

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
            // breathing: base ± 30%
            let breath = sin(drop.breathPhase * .pi * 2)
            return drop.baseRadius * (1.0 + 0.3 * breath)
        } else {
            return drop.baseRadius
        }
    }

    private func renderDrop(on canvas: inout [[Int]], drop: InkDrop, radius r: Double) {
        for y in 0..<height {
            for x in 0..<width {
                let dx = Double(x) - drop.centerX
                let dy = Double(y) - drop.centerY
                let d = sqrt(dx * dx + dy * dy)

                guard d < r else { continue }

                let level: Int
                if useRetina {
                    // 4단계: █(4) ▓(3) ▒(2) ░(1)
                    if d < r * 0.25 { level = 4 }
                    else if d < r * 0.5 { level = 3 }
                    else if d < r * 0.75 { level = 2 }
                    else { level = 1 }
                } else {
                    // 3단계: █(3) ▓(2) ░(1)
                    if d < r * 0.3 { level = 3 }
                    else if d < r * 0.6 { level = 2 }
                    else { level = 1 }
                }

                // idle 상태에서 가장자리 숨김
                if !drop.isActive && !drop.showEdge && level <= 1 {
                    continue
                }

                // 중첩: 기존 값에 더하고 clamp
                canvas[y][x] = min(canvas[y][x] + level, maxLevel)
            }
        }
    }
}
