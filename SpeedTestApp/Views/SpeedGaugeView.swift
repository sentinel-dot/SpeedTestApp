import SwiftUI

private struct GaugeArc: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let lineWidth: CGFloat = 20
        let center = CGPoint(x: rect.midX, y: rect.maxY - 2)
        let radius = min(rect.width, rect.height) / 2 - lineWidth / 2
        return Path { p in
            p.addArc(center: center, radius: radius, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        }
    }
}

struct SpeedGaugeView: View {
    let value: Double
    let unit: String
    let phaseLabel: String
    let gaugeMax: Double
    var isMeasuring: Bool = false

    private let lineWidth: CGFloat = 20

    private var clampedValue: Double {
        min(max(value, 0), gaugeMax)
    }

    private var progress: Double {
        guard gaugeMax > 0 else { return 0 }
        return clampedValue / gaugeMax
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .bottom) {
                GaugeArc(progress: 1)
                    .trim(from: 0, to: 1)
                    .stroke(Color(.systemGray5), lineWidth: lineWidth)
                    .aspectRatio(2, contentMode: .fit)

                GaugeArc(progress: progress)
                    .trim(from: 0, to: progress)
                    .stroke(Color.accentColor, lineWidth: lineWidth)
                    .aspectRatio(2, contentMode: .fit)
                    .animation(.easeOut(duration: 0.2), value: progress)

                VStack(spacing: 4) {
                    if isMeasuring && value == 0 && unit == "ms" {
                        ProgressView()
                            .scaleEffect(0.9)
                            .padding(.vertical, 8)
                    } else {
                        Text(formattedValue)
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText())
                        Text(unit)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Text(phaseLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 28)
            }
        }
    }

    private var formattedValue: String {
        if unit == "ms" {
            return value >= 1 ? String(format: "%.0f", value) : "–"
        }
        if value >= 100 { return String(format: "%.0f", value) }
        if value >= 1 { return String(format: "%.1f", value) }
        return value > 0 ? String(format: "%.2f", value) : "0"
    }
}
