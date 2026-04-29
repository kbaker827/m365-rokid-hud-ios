import Foundation
import Combine

@MainActor
final class HudViewModel: ObservableObject {
    @Published var bleState: M365ConnectionState = .idle
    @Published var discoveredDevices: [ScooterDevice] = []
    @Published var telemetry = ScooterTelemetry()
    @Published var connectedDevice: ScooterDevice?
    @Published var glassesConnected = false
    @Published var glassesClientCount = 0
    @Published var statusText = "Ready"
    @Published var showSpeedAlert = false
    @Published var showBatteryAlert = false

    let settingsStore: SettingsStore
    let bleManager = M365BleManager()
    private let glassesServer = GlassesServer()
    private var cancellables = Set<AnyCancellable>()

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        setupBindings()
        setupGlassesServer()
        glassesServer.start()
    }

    private func setupBindings() {
        bleManager.$state.sink { [weak self] state in
            Task { @MainActor [weak self] in
                self?.bleState = state
                self?.statusText = Self.stateText(state)
                switch state {
                case .connected: self?.glassesServer.broadcastStatus("Connected to scooter")
                case .idle: self?.glassesServer.broadcastStatus("Disconnected")
                case .error(let msg): self?.glassesServer.broadcastStatus("Error: \(msg)")
                default: break
                }
            }
        }.store(in: &cancellables)

        bleManager.$discoveredDevices.sink { [weak self] devices in
            Task { @MainActor [weak self] in self?.discoveredDevices = devices }
        }.store(in: &cancellables)

        bleManager.$connectedDevice.sink { [weak self] device in
            Task { @MainActor [weak self] in self?.connectedDevice = device }
        }.store(in: &cancellables)

        bleManager.$telemetry.sink { [weak self] t in
            Task { @MainActor [weak self] in
                guard let self else { return }
                telemetry = t
                glassesServer.broadcastTelemetry(t)
                checkAlerts(t)
            }
        }.store(in: &cancellables)
    }

    private func setupGlassesServer() {
        glassesServer.onClientConnected = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                glassesClientCount = glassesServer.clientCount
                glassesConnected = true
            }
        }
        glassesServer.onClientDisconnected = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                glassesClientCount = glassesServer.clientCount
                glassesConnected = glassesClientCount > 0
            }
        }
    }

    private func checkAlerts(_ t: ScooterTelemetry) {
        showSpeedAlert = t.speedKmh > settingsStore.settings.maxSpeedAlert && settingsStore.settings.maxSpeedAlert > 0
        showBatteryAlert = t.batteryPercent < settingsStore.settings.lowBatteryAlert && t.batteryPercent > 0
    }

    func startScan() { bleManager.startScan() }
    func stopScan() { bleManager.stopScan() }
    func connect(to device: ScooterDevice) { bleManager.connect(to: device) }
    func disconnect() { bleManager.disconnect() }

    func formatSpeed(_ kmh: Double) -> String {
        if settingsStore.settings.useImperial {
            return String(format: "%.1f mph", kmh * 0.621371)
        }
        return String(format: "%.1f km/h", kmh)
    }

    func formatDistance(_ km: Double) -> String {
        if settingsStore.settings.useImperial {
            return String(format: "%.1f mi", km * 0.621371)
        }
        return String(format: "%.1f km", km)
    }

    private static func stateText(_ state: M365ConnectionState) -> String {
        switch state {
        case .idle: return "Ready"
        case .scanning: return "Scanning..."
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .error(let msg): return "Error: \(msg)"
        }
    }
}
