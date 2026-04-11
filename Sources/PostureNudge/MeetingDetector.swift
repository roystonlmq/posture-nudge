import Foundation
import CoreMediaIO
import CoreAudio
import CoreGraphics
import AppKit

@MainActor
final class MeetingDetector: ObservableObject {
    @Published private(set) var isMeetingActive: Bool = false
    @Published private(set) var isUserIdle: Bool = false
    @Published private(set) var isScreenLocked: Bool = false
    @Published private(set) var cameraInUse: Bool = false
    @Published private(set) var microphoneInUse: Bool = false

    /// Meeting, idle, or screen locked - the scheduler observes this
    @Published private(set) var shouldPause: Bool = false

    private var pollTimer: Timer?
    private var screenSleepObserver: NSObjectProtocol?
    private var screenWakeObserver: NSObjectProtocol?

    // Meeting hysteresis
    private var meetingActiveCount: Int = 0
    private var meetingInactiveCount: Int = 0
    private let meetingEnterThreshold: Int = 5
    private let meetingExitThreshold: Int = 10

    // Config (set by ReminderScheduler from settings)
    var idleThresholdSeconds: TimeInterval = 60
    var meetingDetectionEnabled: Bool = true
    var idleDetectionEnabled: Bool = true

    func start() {
        guard pollTimer == nil else { return }

        Self.enableScreenCaptureDevices()

        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.poll()
            }
        }

        registerScreenNotifications()
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        removeScreenNotifications()
        isMeetingActive = false
        isUserIdle = false
        isScreenLocked = false
        shouldPause = false
        cameraInUse = false
        microphoneInUse = false
        meetingActiveCount = 0
        meetingInactiveCount = 0
    }

    private func poll() {
        if meetingDetectionEnabled {
            pollMeeting()
        } else if isMeetingActive {
            isMeetingActive = false
            meetingActiveCount = 0
            meetingInactiveCount = 0
        }

        if idleDetectionEnabled {
            pollIdle()
        } else if isUserIdle {
            isUserIdle = false
        }

        updateShouldPause()
    }

    private func updateShouldPause() {
        shouldPause = isMeetingActive || isUserIdle || isScreenLocked
    }

    // MARK: - Meeting detection

    private func pollMeeting() {
        let cam = Self.isAnyCameraRunning()
        let mic = Self.isAnyMicrophoneRunning()
        cameraInUse = cam
        microphoneInUse = mic

        if cam || mic {
            meetingActiveCount += 1
            meetingInactiveCount = 0
            if !isMeetingActive && meetingActiveCount >= meetingEnterThreshold {
                isMeetingActive = true
            }
        } else {
            meetingInactiveCount += 1
            meetingActiveCount = 0
            if isMeetingActive && meetingInactiveCount >= meetingExitThreshold {
                isMeetingActive = false
            }
        }
    }

    // MARK: - Idle detection

    private func pollIdle() {
        let idleTime = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState, eventType: .mouseMoved
        )
        let idleKb = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState, eventType: .keyDown
        )
        let idleClick = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState, eventType: .leftMouseDown
        )
        // User is idle if no keyboard, mouse movement, or clicks
        let minIdle = min(idleTime, idleKb, idleClick)
        isUserIdle = minIdle >= idleThresholdSeconds
    }

    // MARK: - Screen lock detection

    private func registerScreenNotifications() {
        guard screenSleepObserver == nil else { return }
        let center = NSWorkspace.shared.notificationCenter

        screenSleepObserver = center.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isScreenLocked = true
                self?.updateShouldPause()
            }
        }

        screenWakeObserver = center.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isScreenLocked = false
                self?.updateShouldPause()
            }
        }
    }

    private func removeScreenNotifications() {
        let center = NSWorkspace.shared.notificationCenter
        if let obs = screenSleepObserver {
            center.removeObserver(obs)
            screenSleepObserver = nil
        }
        if let obs = screenWakeObserver {
            center.removeObserver(obs)
            screenWakeObserver = nil
        }
    }

    // MARK: - CoreMediaIO: camera detection

    nonisolated private static func enableScreenCaptureDevices() {
        var prop = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        var value: UInt32 = 1
        CMIOObjectSetPropertyData(
            CMIOObjectID(kCMIOObjectSystemObject), &prop, 0, nil,
            UInt32(MemoryLayout<UInt32>.size), &value
        )
    }

    nonisolated private static func isAnyCameraRunning() -> Bool {
        var prop = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        var dataSize: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(
            CMIOObjectID(kCMIOObjectSystemObject), &prop, 0, nil, &dataSize
        ) == noErr, dataSize > 0 else { return false }

        let stride = MemoryLayout<CMIODeviceID>.size
        guard stride > 0, Int(dataSize) % stride == 0 else { return false }
        let count = Int(dataSize) / stride
        var deviceIDs = [CMIODeviceID](repeating: 0, count: count)
        guard CMIOObjectGetPropertyData(
            CMIOObjectID(kCMIOObjectSystemObject), &prop, 0, nil, dataSize, &dataSize, &deviceIDs
        ) == noErr else { return false }

        for deviceID in deviceIDs {
            var runningProp = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
            )
            var isRunning: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            if CMIOObjectGetPropertyData(deviceID, &runningProp, 0, nil, size, &size, &isRunning) == noErr,
               isRunning != 0 {
                return true
            }
        }
        return false
    }

    // MARK: - CoreAudio: microphone detection

    nonisolated private static func isAnyMicrophoneRunning() -> Bool {
        var prop = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &prop, 0, nil, &dataSize
        ) == noErr, dataSize > 0 else { return false }

        let stride = MemoryLayout<AudioDeviceID>.size
        guard stride > 0, Int(dataSize) % stride == 0 else { return false }
        let count = Int(dataSize) / stride
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &prop, 0, nil, &dataSize, &deviceIDs
        ) == noErr else { return false }

        for deviceID in deviceIDs {
            // Only check devices with input streams (microphones)
            var inputProp = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(
                deviceID, &inputProp, 0, nil, &streamSize
            ) == noErr, streamSize > 0 else { continue }

            // This device has input capability - check if running
            var runningProp = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var isRunning: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(
                deviceID, &runningProp, 0, nil, &size, &isRunning
            ) == noErr, isRunning != 0 {
                return true
            }
        }
        return false
    }
}
