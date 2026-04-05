import Foundation
import CoreMediaIO
import CoreAudio

@MainActor
final class MeetingDetector: ObservableObject {
    @Published private(set) var isMeetingActive: Bool = false
    @Published private(set) var cameraInUse: Bool = false
    @Published private(set) var microphoneInUse: Bool = false

    private var pollTimer: Timer?
    private var activeCount: Int = 0
    private var inactiveCount: Int = 0

    private let enterThreshold: Int = 5   // 5s of cam/mic active before pausing
    private let exitThreshold: Int = 10   // 10s of cam/mic inactive before resuming

    func start() {
        guard pollTimer == nil else { return }

        // Allow CMIO to see virtual/extension cameras (Zoom, OBS, etc.)
        Self.enableScreenCaptureDevices()

        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.poll()
            }
        }
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        isMeetingActive = false
        cameraInUse = false
        microphoneInUse = false
        activeCount = 0
        inactiveCount = 0
    }

    private func poll() {
        let cam = Self.isAnyCameraRunning()
        let mic = Self.isAnyMicrophoneRunning()
        cameraInUse = cam
        microphoneInUse = mic

        if cam || mic {
            activeCount += 1
            inactiveCount = 0
            if !isMeetingActive && activeCount >= enterThreshold {
                isMeetingActive = true
            }
        } else {
            inactiveCount += 1
            activeCount = 0
            if isMeetingActive && inactiveCount >= exitThreshold {
                isMeetingActive = false
            }
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

        let count = Int(dataSize) / MemoryLayout<CMIODeviceID>.size
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

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
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
