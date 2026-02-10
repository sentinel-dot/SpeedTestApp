import SwiftUI

struct MetricCardView: View {
    let title: String
    let value: Double?
    let unit: String
    let icon: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(Color(red: 59/255, green: 130/255, blue: 246/255))

            if let v = value {
                Text(formattedValue(v) + " " + unit)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(Color(red: 28/255, green: 28/255, blue: 30/255))
                    .contentTransition(.numericText())
            } else {
                Text("--")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(Color(red: 142/255, green: 142/255, blue: 147/255))
            }

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(red: 142/255, green: 142/255, blue: 147/255))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
    }

    private func formattedValue(_ v: Double) -> String {
        if v >= 1000 {
            return String(format: "%.1f", v)
        } else if v >= 1 {
            return String(format: "%.2f", v)
        } else {
            return String(format: "%.2f", v)
        }
    }
}
