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

    /// Clamps all user-facing intervals to valid range (1-120 min).
    func sanitized() -> NudgeSettings {
        var s = self
        s.postureIntervalMinutes = postureIntervalMinutes.clamped(to: 1...120)
        s.blinkIntervalMinutes = blinkIntervalMinutes.clamped(to: 1...120)
        s.eyeBreakIntervalMinutes = eyeBreakIntervalMinutes.clamped(to: 1...120)
        s.idleThresholdMinutes = idleThresholdMinutes.clamped(to: 1...120)
        return s
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    @Published var settings: NudgeSettings {
        didSet { save() }
    }

    private let defaults: UserDefaults
    private let key = "com.roystonlee.posture-nudge.settings"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "com.roystonlee.posture-nudge.settings"),
           let decoded = try? JSONDecoder().decode(NudgeSettings.self, from: data) {
            settings = decoded.sanitized()
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
