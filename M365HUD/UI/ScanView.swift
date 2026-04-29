import SwiftUI

struct ScanView: View {
    @ObservedObject var vm: HudViewModel

    var body: some View {
        NavigationStack {
            VStack {
                if case .scanning = vm.bleState {
                    ProgressView("Scanning for scooters...")
                        .padding()
                }

                List(vm.discoveredDevices) { device in
                    Button {
                        vm.connect(to: device)
                    } label: {
                        HStack {
                            Image(systemName: "bicycle")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                                .frame(width: 44)
                            VStack(alignment: .leading) {
                                Text(device.name)
                                    .font(.headline)
                                Text("RSSI: \(device.rssi) dBm")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .listStyle(.plain)

                if vm.discoveredDevices.isEmpty, case .idle = vm.bleState {
                    ContentUnavailableView(
                        "No Scooters Found",
                        systemImage: "bicycle",
                        description: Text("Tap Scan to search for M365/Ninebot scooters.")
                    )
                }

                Spacer()

                Button {
                    if case .scanning = vm.bleState { vm.stopScan() }
                    else { vm.startScan() }
                } label: {
                    Label(
                        (vm.bleState == .scanning ? "Stop" : "Scan"),
                        systemImage: vm.bleState == .scanning ? "stop.circle.fill" : "antenna.radiowaves.left.and.right"
                    )
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(vm.bleState == .scanning ? Color.red : Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding()
            }
            .navigationTitle("Find Scooter")
        }
    }
}

// Workaround: make M365ConnectionState Equatable for the == check
extension M365ConnectionState: Equatable {
    static func == (lhs: M365ConnectionState, rhs: M365ConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.scanning, .scanning), (.connecting, .connecting), (.connected, .connected):
            return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}
