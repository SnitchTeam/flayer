import Foundation
import CoreAudio

struct AudioOutputDevice: Identifiable, Equatable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let sampleRate: Double
    let maxSampleRate: Double

    static func == (lhs: AudioOutputDevice, rhs: AudioOutputDevice) -> Bool {
        lhs.uid == rhs.uid
    }
}

enum AudioDeviceManager {

    static func getOutputDevices() -> [AudioOutputDevice] {
        var size: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size
        ) == noErr else { return [] }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids
        ) == noErr else { return [] }

        return ids.compactMap { outputDevice(for: $0) }
    }

    static func getDefaultDeviceID() -> AudioDeviceID {
        var id: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id
        )
        return id
    }

    private static func outputDevice(for deviceID: AudioDeviceID) -> AudioOutputDevice? {
        guard hasOutputChannels(deviceID) else { return nil }

        let name = getStringProperty(deviceID, selector: kAudioObjectPropertyName) ?? "Unknown"
        let uid = getStringProperty(deviceID, selector: kAudioDevicePropertyDeviceUID) ?? ""

        // Current nominal sample rate
        var srAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var sampleRate: Float64 = 0
        var srSize = UInt32(MemoryLayout<Float64>.size)
        AudioObjectGetPropertyData(deviceID, &srAddress, 0, nil, &srSize, &sampleRate)

        // Max supported sample rate
        let maxRate = getMaxSampleRate(deviceID)

        return AudioOutputDevice(
            id: deviceID, uid: uid, name: name,
            sampleRate: sampleRate,
            maxSampleRate: maxRate > 0 ? maxRate : sampleRate
        )
    }

    /// Set the nominal sample rate on a device. Returns true on success.
    @discardableResult
    static func setSampleRate(_ rate: Double, deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var sampleRate = Float64(rate)
        let size = UInt32(MemoryLayout<Float64>.size)
        return AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &sampleRate) == noErr
    }

    /// Set hog mode (exclusive access) on a device. Returns true on success.
    @discardableResult
    static func setHogMode(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyHogMode,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var pid = ProcessInfo.processInfo.processIdentifier
        let size = UInt32(MemoryLayout<pid_t>.size)
        return AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &pid) == noErr
    }

    /// Release hog mode on a device.
    @discardableResult
    static func releaseHogMode(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyHogMode,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var pid: pid_t = -1
        let size = UInt32(MemoryLayout<pid_t>.size)
        return AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &pid) == noErr
    }

    /// Get the current hog mode pid (-1 if not hogged)
    static func getHogModePid(_ deviceID: AudioDeviceID) -> pid_t {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyHogMode,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var pid: pid_t = -1
        var size = UInt32(MemoryLayout<pid_t>.size)
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &pid)
        return pid
    }

    /// Set the physical stream format (for bit-perfect output)
    @discardableResult
    static func setPhysicalFormat(deviceID: AudioDeviceID, sampleRate: Double, bitsPerChannel: UInt32) -> Bool {
        // Find output streams
        var streamsAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var streamsSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &streamsAddress, 0, nil, &streamsSize) == noErr,
              streamsSize > 0 else { return false }

        let streamCount = Int(streamsSize) / MemoryLayout<AudioStreamID>.size
        var streamIDs = [AudioStreamID](repeating: 0, count: streamCount)
        guard AudioObjectGetPropertyData(deviceID, &streamsAddress, 0, nil, &streamsSize, &streamIDs) == noErr
        else { return false }

        for streamID in streamIDs {
            var formatAddress = AudioObjectPropertyAddress(
                mSelector: kAudioStreamPropertyPhysicalFormat,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            // Get available formats to find a matching one
            var availAddress = AudioObjectPropertyAddress(
                mSelector: kAudioStreamPropertyAvailablePhysicalFormats,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var availSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(streamID, &availAddress, 0, nil, &availSize) == noErr,
                  availSize > 0 else { continue }

            let rangeCount = Int(availSize) / MemoryLayout<AudioStreamRangedDescription>.size
            var ranges = [AudioStreamRangedDescription](repeating: AudioStreamRangedDescription(), count: rangeCount)
            guard AudioObjectGetPropertyData(streamID, &availAddress, 0, nil, &availSize, &ranges) == noErr
            else { continue }

            // Find best matching format: exact sample rate, matching bit depth, PCM
            if let match = ranges.first(where: { range in
                let fmt = range.mFormat
                return fmt.mSampleRate == sampleRate &&
                    fmt.mBitsPerChannel == bitsPerChannel &&
                    fmt.mFormatID == kAudioFormatLinearPCM
            }) ?? ranges.first(where: { range in
                let fmt = range.mFormat
                return range.mSampleRateRange.mMinimum <= sampleRate &&
                    sampleRate <= range.mSampleRateRange.mMaximum &&
                    fmt.mBitsPerChannel == bitsPerChannel &&
                    fmt.mFormatID == kAudioFormatLinearPCM
            }) {
                var format = match.mFormat
                format.mSampleRate = sampleRate
                let formatSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
                if AudioObjectSetPropertyData(streamID, &formatAddress, 0, nil, formatSize, &format) == noErr {
                    return true
                }
            }
        }
        return false
    }

    private static func getMaxSampleRate(_ deviceID: AudioDeviceID) -> Double {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyAvailableNominalSampleRates,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr,
              size > 0 else { return 0 }

        let count = Int(size) / MemoryLayout<AudioValueRange>.size
        var ranges = [AudioValueRange](repeating: AudioValueRange(), count: count)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &ranges) == noErr
        else { return 0 }

        return ranges.map(\.mMaximum).max() ?? 0
    }

    private static func hasOutputChannels(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr,
              size > 0 else { return false }

        let ptr = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { ptr.deallocate() }
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, ptr) == noErr
        else { return false }

        let listPtr = ptr.assumingMemoryBound(to: AudioBufferList.self)
        let buffers = UnsafeMutableAudioBufferListPointer(listPtr)
        return buffers.contains { $0.mNumberChannels > 0 }
    }

    private static func getStringProperty(
        _ deviceID: AudioDeviceID,
        selector: AudioObjectPropertySelector
    ) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value) == noErr,
              let cfString = value?.takeRetainedValue()
        else { return nil }
        return cfString as String
    }
}
