import XCTest
@testable import PostureNudge

// MARK: - Mock overlay

@MainActor
final class MockOverlay: OverlayShowing {
    var shown: [ReminderType] = []
    var dismissCount = 0

    func show(_ type: ReminderType) { shown.append(type) }
    func dismiss() { dismissCount += 1 }
}

// MARK: - NudgeSettings tests

final class NudgeSettingsTests: XCTestCase {
    func testDefaultValues() {
        let s = NudgeSettings.default
        XCTAssertTrue(s.postureEnabled)
        XCTAssertEqual(s.postureIntervalMinutes, 30)
        XCTAssertTrue(s.blinkEnabled)
        XCTAssertEqual(s.blinkIntervalMinutes, 20)
        XCTAssertTrue(s.eyeBreakEnabled)
        XCTAssertEqual(s.eyeBreakIntervalMinutes, 20)
    }

    func testCodableRoundTrip() throws {
        var s = NudgeSettings.default
        s.postureEnabled = false
        s.blinkIntervalMinutes = 45
        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(NudgeSettings.self, from: data)
        XCTAssertEqual(s, decoded)
    }

    func testEquality() {
        let a = NudgeSettings.default
        var b = NudgeSettings.default
        XCTAssertEqual(a, b)
        b.postureEnabled = false
        XCTAssertNotEqual(a, b)
    }
}

// MARK: - SettingsStore tests

final class SettingsStoreTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let suite = "com.test.posturenudge.\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    @MainActor
    func testLoadsDefaults() {
        let store = SettingsStore(defaults: makeDefaults())
        XCTAssertEqual(store.settings, .default)
    }

    @MainActor
    func testPersistsChanges() {
        let defaults = makeDefaults()
        let store = SettingsStore(defaults: defaults)
        store.settings.postureEnabled = false
        store.settings.blinkIntervalMinutes = 10

        let store2 = SettingsStore(defaults: defaults)
        XCTAssertFalse(store2.settings.postureEnabled)
        XCTAssertEqual(store2.settings.blinkIntervalMinutes, 10)
    }

    @MainActor
    func testHandlesCorruptData() {
        let defaults = makeDefaults()
        defaults.set(Data("garbage".utf8), forKey: "nudge.settings")
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.settings, .default)
    }
}

// MARK: - ReminderType tests

final class ReminderTypeTests: XCTestCase {
    func testTitlesNotEmpty() {
        let types: [ReminderType] = [.posture, .blink, .eyeBreak]
        for t in types {
            XCTAssertFalse(t.title.isEmpty)
            XCTAssertFalse(t.body.isEmpty)
        }
    }
}

// MARK: - ReminderScheduler tests

final class ReminderSchedulerTests: XCTestCase {
    @MainActor
    func testTimersCreatedWhenEnabled() {
        let defaults = UserDefaults(suiteName: "com.test.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        let mock = MockOverlay()
        let scheduler = ReminderScheduler(settingsStore: store, overlayManager: mock)

        XCTAssertNotNil(scheduler.postureNextFire)
        XCTAssertNotNil(scheduler.blinkNextFire)
        XCTAssertNotNil(scheduler.eyeBreakNextFire)
    }

    @MainActor
    func testTimersNilWhenDisabled() {
        let defaults = UserDefaults(suiteName: "com.test.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        store.settings.postureEnabled = false
        store.settings.blinkEnabled = false
        store.settings.eyeBreakEnabled = false

        let mock = MockOverlay()
        let scheduler = ReminderScheduler(settingsStore: store, overlayManager: mock)

        XCTAssertNil(scheduler.postureNextFire)
        XCTAssertNil(scheduler.blinkNextFire)
        XCTAssertNil(scheduler.eyeBreakNextFire)
    }

    @MainActor
    func testNextFireIsInTheFuture() {
        let defaults = UserDefaults(suiteName: "com.test.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        let mock = MockOverlay()
        let scheduler = ReminderScheduler(settingsStore: store, overlayManager: mock)

        let now = Date()
        XCTAssertGreaterThan(scheduler.postureNextFire!, now)
        XCTAssertGreaterThan(scheduler.blinkNextFire!, now)
        XCTAssertGreaterThan(scheduler.eyeBreakNextFire!, now)
    }

    @MainActor
    func testNextFireMatchesInterval() {
        let defaults = UserDefaults(suiteName: "com.test.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        store.settings.postureIntervalMinutes = 15
        store.settings.blinkIntervalMinutes = 10

        let mock = MockOverlay()
        let now = Date()
        let scheduler = ReminderScheduler(settingsStore: store, overlayManager: mock)

        let postureExpected = now.addingTimeInterval(15 * 60)
        let blinkExpected = now.addingTimeInterval(10 * 60)

        // Allow 2 second tolerance for test execution time
        XCTAssertEqual(scheduler.postureNextFire!.timeIntervalSince1970, postureExpected.timeIntervalSince1970, accuracy: 2)
        XCTAssertEqual(scheduler.blinkNextFire!.timeIntervalSince1970, blinkExpected.timeIntervalSince1970, accuracy: 2)
    }

    @MainActor
    func testSettingsChangeReconfiguresTimers() async throws {
        let defaults = UserDefaults(suiteName: "com.test.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        let mock = MockOverlay()
        let scheduler = ReminderScheduler(settingsStore: store, overlayManager: mock)

        XCTAssertNotNil(scheduler.postureNextFire)

        store.settings.postureEnabled = false

        // Wait for debounce (300ms) + a bit of margin
        try await Task.sleep(for: .milliseconds(500))

        XCTAssertNil(scheduler.postureNextFire)
    }
}

// MARK: - BreakCountdown tests

final class BreakCountdownTests: XCTestCase {
    @MainActor
    func testInitialValue() {
        let c = BreakCountdown(seconds: 20)
        XCTAssertEqual(c.remaining, 20)
    }

    @MainActor
    func testDecrement() {
        let c = BreakCountdown(seconds: 5)
        c.remaining -= 1
        XCTAssertEqual(c.remaining, 4)
    }
}

// MARK: - OverlayManager queue tests

final class OverlayManagerQueueTests: XCTestCase {
    @MainActor
    func testMockOverlayRecordsShows() {
        let mock = MockOverlay()
        mock.show(.posture)
        mock.show(.blink)
        mock.show(.eyeBreak)
        XCTAssertEqual(mock.shown, [.posture, .blink, .eyeBreak])
    }

    @MainActor
    func testMockOverlayRecordsDismiss() {
        let mock = MockOverlay()
        mock.dismiss()
        mock.dismiss()
        XCTAssertEqual(mock.dismissCount, 2)
    }
}
