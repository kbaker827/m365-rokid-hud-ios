import SwiftUI

struct DashboardView: View {
    @ObservedObject var vm: HudViewModel

    var body: some View {
        VStack(spacing: 24) {
            // Speed ring
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 18)
                Circle()
                    .trim(from: 0, to: min(vm.telemetry.speedKmh / 35.0, 1.0))
                    .stroke(speedColor, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.3), value: vm.telemetry.speedKmh)
                VStack(spacing: 2) {
                    Text(String(format: "%.1f", vm.settingsStore.settings.useImperial ? vm.telemetry.speedKmh * 0.621371 : vm.telemetry.speedKmh))
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                    Text(vm.settingsStore.settings.useImperial ? "mph" : "km/h")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 220, height: 220)
            .padding(.top, 20)

            // Stats grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                StatCard(title: "Battery", value: "\(vm.telemetry.batteryPercent)%",
                         icon: batteryIcon, color: batteryColor)
                StatCard(title: "Temp", value: String(format: "%.0f°C", vm.telemetry.tempCelsius),
                         icon: "thermometer.medium", color: .orange)
                StatCard(title: "Trip", value: "\(vm.telemetry.tripMeters) m",
                         icon: "location.fill", color: .blue)
                StatCard(title: "Range", value: vm.formatDistance(vm.telemetry.remainingKm),
                         icon: "battery.100", color: .green)
                StatCard(title: "Total", value: vm.formatDistance(vm.telemetry.totalKm),
                         icon: "gauge", color: .purple)
                StatCard(title: "Error", value: vm.telemetry.errorCode == 0 ? "None" : "E\(vm.telemetry.errorCode)",
                         icon: vm.telemetry.errorCode == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                         color: vm.telemetry.errorCode == 0 ? .green : .red)
            }
            .padding(.horizontal)

            if vm.showSpeedAlert {
                alertBanner("Speed limit exceeded!", color: .orange)
            }
            if vm.showBatteryAlert {
                alertBanner("Low battery — \(vm.telemetry.batteryPercent)%", color: .red)
            }

            Spacer()

            Button(action: vm.disconnect) {
                Label("Disconnect", systemImage: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .padding()
            }
        }
    }

    private var speedColor: Color {
        let s = vm.telemetry.speedKmh
        let limit = vm.settingsStore.settings.maxSpeedAlert
        if s > limit { return .red }
        if s > limit * 0.85 { return .orange }
        return .accentColor
    }

    private var batteryColor: Color {
        let b = vm.telemetry.batteryPercent
        if b < 15 { return .red }
        if b < 30 { return .orange }
        return .green
    }

    private var batteryIcon: String {
        let b = vm.telemetry.batteryPercent
        if b > 75 { return "battery.100" }
        if b > 50 { return "battery.75" }
        if b > 25 { return "battery.50" }
        return "battery.25"
    }

    private func alertBanner(_ text: String, color: Color) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(text).font(.subheadline.bold())
        }
        .foregroundColor(.white)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(color)
        .clipShape(Capsule())
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon).foregroundColor(color)
                Text(title).font(.caption).foregroundColor(.secondary)
            }
            Text(value).font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
