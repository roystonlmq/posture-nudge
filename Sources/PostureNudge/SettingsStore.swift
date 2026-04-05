import Foundation

struct NudgeSettings: Codable, Equatable {
    var postureEnabled: Bool = true
    var postureIntervalMinutes: Int = 30
    var blinkEnabled: Bool = true
    var blinkIntervalMinutes: Int = 20
    var eyeBreakEnabled: Bool = true
    var eyeBreakIntervalMinutes: Int = 20
    var meetingDetectionEnabled: Bool = true
    var idleDetectionEnabled: Bool = true
    var idleThresholdMinutes: Int = 1

    static let `default` = NudgeSettings()
}

@MainActor
final class SettingsStore: ObservableObject {
    @Published var settings: NudgeSettings {
        didSet { save() }
    }

    private let defaults: UserDefaults
    private let key = "nudge.settings"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "nudge.settings"),
           let decoded = try? JSONDecoder().decode(NudgeSettings.self, from: data) {
            settings = decoded
        } else {
            settings = .default
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: key)
        }
    }
}
