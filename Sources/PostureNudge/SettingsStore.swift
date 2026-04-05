import Foundation

struct NudgeSettings: Codable, Equatable {
    var postureEnabled: Bool = true
    var postureIntervalMinutes: Int = 30
    var blinkEnabled: Bool = true
    var blinkIntervalMinutes: Int = 20
    var eyeBreakEnabled: Bool = true
    var eyeBreakIntervalMinutes: Int = 20

    static let `default` = NudgeSettings()
}

@MainActor
final class SettingsStore: ObservableObject {
    @Published var settings: NudgeSettings {
        didSet { save() }
    }

    private let key = "nudge.settings"

    init() {
        if let data = UserDefaults.standard.data(forKey: "nudge.settings"),
           let decoded = try? JSONDecoder().decode(NudgeSettings.self, from: data) {
            settings = decoded
        } else {
            settings = .default
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
