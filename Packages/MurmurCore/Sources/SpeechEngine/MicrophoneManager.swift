import AVFoundation
import CoreAudio
import Foundation

public struct AudioInputDevice: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let isDefault: Bool
    public let isBluetooth: Bool
    public let sampleRate: Double

    public init(id: String, name: String, isDefault: Bool, isBluetooth: Bool = false, sampleRate: Double = 0) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
        self.isBluetooth = isBluetooth
        self.sampleRate = sampleRate
    }
}

public final class MicrophoneManager: @unchecked Sendable {
    public init() {}

    /// All available audio input devices, with Bluetooth flagged.
    public var availableInputDevices: [AudioInputDevice] {
        #if os(macOS)
        return enumerateInputDevices()
        #else
        return []
        #endif
    }

    /// Recommended device for transcription: prefers non-Bluetooth, highest sample rate.
    public var recommendedInputDevice: AudioInputDevice? {
        let devices = availableInputDevices
        // Prefer non-Bluetooth, then highest sample rate, then default wins ties
        let sorted = devices.sorted { lhs, rhs in
            if lhs.isBluetooth != rhs.isBluetooth {
                return !lhs.isBluetooth // non-Bluetooth first
            }
            if lhs.sampleRate != rhs.sampleRate {
                return lhs.sampleRate > rhs.sampleRate // higher sample rate first
            }
            return lhs.isDefault && !rhs.isDefault // default wins ties
        }
        return sorted.first
    }

    public var defaultInputFormat: AVAudioFormat? {
        let engine = AVAudioEngine()
        return engine.inputNode.outputFormat(forBus: 0)
    }

    // MARK: - CoreAudio Device Enumeration

    #if os(macOS)
    private func enumerateInputDevices() -> [AudioInputDevice] {
        let defaultID = getDefaultInputDeviceID()
        let deviceIDs = getAllAudioDeviceIDs()

        return deviceIDs.compactMap { deviceID -> AudioInputDevice? in
            // Check if this device has input channels
            guard hasInputChannels(deviceID) else { return nil }

            let name = getDeviceName(deviceID) ?? "Unknown Device"
            let transportType = getTransportType(deviceID)
            let sampleRate = getNominalSampleRate(deviceID)

            let isBluetooth = transportType == kAudioDeviceTransportTypeBluetooth
                || transportType == kAudioDeviceTransportTypeBluetoothLE

            return AudioInputDevice(
                id: String(deviceID),
                name: name + (isBluetooth ? " (Bluetooth)" : ""),
                isDefault: deviceID == defaultID,
                isBluetooth: isBluetooth,
                sampleRate: sampleRate
            )
        }
    }

    private func getDefaultInputDeviceID() -> AudioDeviceID {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &deviceID
        )
        return deviceID
    }

    private func getAllAudioDeviceIDs() -> [AudioDeviceID] {
        var size: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size
        ) == noErr else { return [] }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &devices
        ) == noErr else { return [] }

        return devices
    }

    private func hasInputChannels(_ deviceID: AudioDeviceID) -> Bool {
        var size: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr else {
            return false
        }

        let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
        defer { bufferListPointer.deallocate() }

        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, bufferListPointer) == noErr else {
            return false
        }

        let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)
        return bufferList.reduce(0) { $0 + Int($1.mNumberChannels) } > 0
    }

    private func getDeviceName(_ deviceID: AudioDeviceID) -> String? {
        var size: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr else {
            return nil
        }

        var name: Unmanaged<CFString>?
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &name) == noErr,
              let cfName = name?.takeRetainedValue() else {
            return nil
        }
        return cfName as String
    }

    private func getTransportType(_ deviceID: AudioDeviceID) -> UInt32 {
        var transportType: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &transportType)
        return transportType
    }

    private func getNominalSampleRate(_ deviceID: AudioDeviceID) -> Double {
        var sampleRate: Float64 = 0
        var size = UInt32(MemoryLayout<Float64>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &sampleRate)
        return sampleRate
    }
    #endif
}
