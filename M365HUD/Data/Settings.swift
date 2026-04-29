import Foundation

struct HudSettings: Codable {
    var useImperial: Bool = false
    var maxSpeedAlert: Double = 25.0  // km/h
    var lowBatteryAlert: Int = 20     // %
}

final class SettingsStore: ObservableObject {
    @Published var settings: HudSettings {
        didSet { save() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: "m365_settings"),
           let decoded = try? JSONDecoder().decode(HudSettings.self, from: data) {
            settings = decoded
        } else {
            settings = HudSettings()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "m365_settings")
        }
    }
}
