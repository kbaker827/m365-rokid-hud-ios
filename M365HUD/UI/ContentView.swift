import SwiftUI

struct ContentView: View {
    @StateObject private var settingsStore = SettingsStore()
    @StateObject private var vm: HudViewModel
    @State private var showSettings = false

    init() {
        let ss = SettingsStore()
        _settingsStore = StateObject(wrappedValue: ss)
        _vm = StateObject(wrappedValue: HudViewModel(settingsStore: ss))
    }

    var body: some View {
        NavigationStack {
            Group {
                if case .connected = vm.bleState {
                    DashboardView(vm: vm)
                } else {
                    ScanView(vm: vm)
                }
            }
            .navigationTitle("M365 HUD")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    glassesIndicator
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(store: settingsStore)
        }
    }

    private var glassesIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(vm.glassesConnected ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            Text(vm.glassesConnected ? "\(vm.glassesClientCount) glasses" : "No glasses")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
