import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Units") {
                    Toggle("Imperial (mph / mi)", isOn: $store.settings.useImperial)
                }
                Section("Alerts") {
                    HStack {
                        Text("Speed alert")
                        Spacer()
                        Text(store.settings.useImperial
                             ? String(format: "%.0f mph", store.settings.maxSpeedAlert * 0.621371)
                             : String(format: "%.0f km/h", store.settings.maxSpeedAlert))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $store.settings.maxSpeedAlert, in: 5...50, step: 5)
                    HStack {
                        Text("Low battery alert")
                        Spacer()
                        Text("\(store.settings.lowBatteryAlert)%")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: Binding(
                        get: { Double(store.settings.lowBatteryAlert) },
                        set: { store.settings.lowBatteryAlert = Int($0) }
                    ), in: 5...50, step: 5)
                }
                Section("Glasses (TCP :8086)") {
                    Text("Connect Rokid glasses to port 8086 on this phone's IP to receive live telemetry as JSON lines.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
