import SwiftUI

final class AnimationSettings: ObservableObject {
    static let shared = AnimationSettings()

    @AppStorage("breathSpeed") var breathSpeed: Double = 0.5      // 0=느림, 1=빠름
    @AppStorage("breathAmplitude") var breathAmplitude: Double = 0.55
    @AppStorage("driftSpeed") var driftSpeed: Double = 0.3
    @AppStorage("growRate") var growRate: Double = 0.5
    @AppStorage("idleTimeout") var idleTimeout: Double = 30

    /// breathSpeed(0~1) → runningCycleTicks
    var runningCycleTicks: Int {
        // 0=60ticks(6초), 0.5=35ticks(3.5초), 1=10ticks(1초)
        Int(60 - 50 * breathSpeed)
    }

    var waitingCycleTicks: Int {
        runningCycleTicks * 2
    }

    /// driftSpeed(0~1) → 실제 속도 범위
    var driftRange: ClosedRange<Double> {
        let base = 0.005 + driftSpeed * 0.04
        return (base * 0.5)...(base * 1.5)
    }

    /// growRate(0~1) → 실제 증가율
    var actualGrowRate: Double {
        0.001 + growRate * 0.01
    }
}

struct SettingsView: View {
    @ObservedObject var settings = AnimationSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Animation")
                .font(.headline)

            settingRow("Breath", value: $settings.breathSpeed,
                       low: "Slow", high: "Fast")
            settingRow("Amplitude", value: $settings.breathAmplitude,
                       low: "Subtle", high: "Bold", range: 0.2...0.8)
            settingRow("Drift", value: $settings.driftSpeed,
                       low: "Still", high: "Flow")
            settingRow("Spread", value: $settings.growRate,
                       low: "None", high: "Fast")

            Divider()

            Text("Monitor")
                .font(.headline)

            HStack {
                Text("Idle after")
                Spacer()
                Text("\(Int(settings.idleTimeout))s")
                    .monospacedDigit()
                    .frame(width: 36, alignment: .trailing)
            }
            Slider(value: $settings.idleTimeout, in: 10...120, step: 5)
        }
        .padding()
        .frame(width: 240)
    }

    private func settingRow(_ label: String, value: Binding<Double>,
                            low: String, high: String,
                            range: ClosedRange<Double> = 0...1) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.subheadline)
            HStack(spacing: 4) {
                Text(low)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
                Slider(value: value, in: range)
                Text(high)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .leading)
            }
        }
    }
}
