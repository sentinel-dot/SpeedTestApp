import SwiftUI

struct StartButtonView: View {
    let isRunning: Bool
    let action: () -> Void

    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.6

    var body: some View {
        ZStack {
            if isRunning {
                Circle()
                    .stroke(Color.red.opacity(pulseOpacity), lineWidth: 4)
                    .frame(width: 88, height: 88)
                    .scaleEffect(pulseScale)
            }

            Button(action: action) {
                Text(isRunning ? "STOP" : "START")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 80, height: 80)
                    .background(isRunning ? Color.red : Color(red: 59/255, green: 130/255, blue: 246/255))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            if isRunning {
                startPulseAnimation()
            }
        }
        .onChange(of: isRunning) { _, running in
            if running {
                startPulseAnimation()
            } else {
                pulseScale = 1.0
                pulseOpacity = 0.6
            }
        }
    }

    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.15
            pulseOpacity = 0.2
        }
    }
}
