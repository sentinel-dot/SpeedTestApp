import SwiftUI

struct ContentView: View {
    @State private var viewModel = SpeedTestViewModel()

    private var isRunning: Bool {
        switch viewModel.status {
        case .measuringDownload, .measuringUpload, .measuringPing:
            return true
        default:
            return false
        }
    }

    private var gaugeValue: Double {
        switch viewModel.status {
        case .measuringDownload, .measuringUpload:
            return viewModel.currentSpeed
        case .measuringPing:
            return viewModel.result.ping ?? 0
        case .done:
            if let ping = viewModel.result.ping { return ping }
            return viewModel.result.download ?? 0
        case .idle, .error:
            return 0
        }
    }

    private var gaugeUnit: String {
        switch viewModel.status {
        case .measuringDownload, .measuringUpload:
            return "Mbps"
        case .measuringPing:
            return "ms"
        case .done:
            return viewModel.result.ping != nil ? "ms" : "Mbps"
        default:
            return "Mbps"
        }
    }

    private var phaseLabel: String {
        switch viewModel.status {
        case .measuringDownload: return "Download"
        case .measuringUpload: return "Upload"
        case .measuringPing: return "Ping"
        case .done: return "Ping"
        default: return "Download"
        }
    }

    private var gaugeMax: Double {
        gaugeUnit == "ms" ? 200 : 1000
    }

    private var isMeasuringPingWithoutValue: Bool {
        viewModel.status == .measuringPing && viewModel.result.ping == nil
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    SpeedGaugeView(
                        value: gaugeValue,
                        unit: gaugeUnit,
                        phaseLabel: phaseLabel,
                        gaugeMax: gaugeMax,
                        isMeasuring: isMeasuringPingWithoutValue
                    )
                    .padding(.top, 20)
                    .padding(.horizontal, 24)

                    if case .error(let message) = viewModel.status {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 12)
                    }

                    if case .done = viewModel.status {
                        resultSection
                    }

                    phaseIndicator
                        .padding(.top, 24)

                    Spacer(minLength: 24)

                    if case .error = viewModel.status {
                        Button("Erneut versuchen") {
                            Task { await viewModel.startTest() }
                        }
                        .font(.headline)
                        .foregroundStyle(Color.accentColor)
                        .padding(.top, 8)
                    }

                    StartButtonView(isRunning: isRunning) {
                        if isRunning {
                            viewModel.stopTest()
                        } else {
                            viewModel.reset()
                            Task { await viewModel.startTest() }
                        }
                    }
                    .padding(.top, 28)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private var phaseIndicator: some View {
        HStack(spacing: 12) {
            PhaseChip(title: "Download", isActive: isPhaseActive(.measuringDownload), isDone: viewModel.result.download != nil)
            PhaseChip(title: "Upload", isActive: isPhaseActive(.measuringUpload), isDone: viewModel.result.upload != nil)
            PhaseChip(title: "Ping", isActive: isPhaseActive(.measuringPing), isDone: viewModel.result.ping != nil)
        }
        .padding(.horizontal, 24)
    }

    private func isPhaseActive(_ status: TestStatus) -> Bool {
        viewModel.status == status
    }

    private var resultSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                ResultRow(label: "Download", value: viewModel.result.download, unit: "Mbps")
                ResultRow(label: "Upload", value: viewModel.result.upload, unit: "Mbps")
            }
            ResultRow(label: "Ping", value: viewModel.result.ping, unit: "ms")
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
}

private struct PhaseChip: View {
    let title: String
    let isActive: Bool
    let isDone: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isActive ? Color.white : (isDone ? Color.secondary : Color.secondary.opacity(0.6)))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isActive ? Color.accentColor : Color(.systemGray5))
            )
    }
}

private struct ResultRow: View {
    let label: String
    let value: Double?
    let unit: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            if let v = value {
                Text(formatValue(v) + " " + unit)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            } else {
                Text("–")
                    .font(.body)
                    .foregroundStyle(Color.secondary.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func formatValue(_ v: Double) -> String {
        if unit == "ms" { return String(format: "%.0f", v) }
        if v >= 100 { return String(format: "%.0f", v) }
        if v >= 1 { return String(format: "%.1f", v) }
        return String(format: "%.2f", v)
    }
}

#Preview {
    ContentView()
}
