import AVFoundation
#if os(macOS)
import CoreAudio
import AudioToolbox
#elseif os(iOS)
import UIKit
#endif

enum PlayerState: String {
    case playing, paused, stopped
}

enum RepeatMode: String {
    case off, all, one
}

@Observable
@MainActor
final class AudioEngine {
    var state: PlayerState = .stopped
    var position: Double = 0
    var duration: Double = 0
    var currentTrack: Track?
    var queue: [Track] = []
    var queueIndex: Int = -1
    var volume: Float = 1.0
    var shuffle: Bool = false
    var repeatMode: RepeatMode = .off
    var replayGainEnabled: Bool = false
    var replayGainMode: String = "track"  // "track" or "album"
    var gaplessEnabled: Bool = true
    private var originalQueue: [Track] = []
    private var nextAudioFile: AVAudioFile?
    #if os(macOS)
    var availableDevices: [AudioOutputDevice] = []
    var currentDeviceUID: String = ""
    var exclusiveModeEnabled: Bool = false
    /// Tracks the device ID where we acquired hog mode
    private var hoggedDeviceID: AudioDeviceID?
    /// Tracks the device ID and its original sample rate before we changed it
    private var savedDeviceState: (deviceID: AudioDeviceID, sampleRate: Double)?
    #elseif os(iOS)
    /// Maps folder paths to their security-scoped URLs for sandbox access
    var securityScopedFolderURLs: [String: URL] = [:]
    /// The security-scoped URL currently being accessed for playback
    private var activeSecurityScopedURL: URL?
    #endif

    private var engine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()
    private var eqNode = AVAudioUnitEQ(numberOfBands: 10)
    private var audioFile: AVAudioFile?
    private var positionTimer: Timer?
    private var seekOffset: Double = 0
    private var playbackGeneration: Int = 0
    private var widgetSyncCounter: Int = 0

    init() {
        engine.attach(playerNode)
        engine.attach(eqNode)
        eqNode.bypass = true
        #if os(macOS)
        refreshDevices()
        #elseif os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
        setupAudioSessionObservers()
        #endif
    }

    // MARK: - Device Management

    #if os(macOS)
    func refreshDevices() {
        availableDevices = AudioDeviceManager.getOutputDevices()
    }

    func setOutputDevice(uid: String) {
        // Release hog/sample rate on the OLD device before switching
        restoreDeviceSettings()
        currentDeviceUID = uid

        guard let file = audioFile, state == .playing || state == .paused else { return }

        let wasPlaying = state == .playing
        let savedPosition = position

        playerNode.stop()
        if engine.isRunning { engine.stop() }

        do {
            connectNodes(format: file.processingFormat)
            applyOutputDevice()
            applyBitPerfectSettings(for: file.processingFormat)
            try engine.start()
            schedulePlayback(from: savedPosition)

            if wasPlaying {
                playerNode.play()
                state = .playing
                startPositionTimer()
            } else {
                state = .paused
            }
        } catch {
            state = .stopped
        }
    }

    private func currentOutputDeviceID() -> AudioDeviceID {
        if currentDeviceUID.isEmpty {
            return AudioDeviceManager.getDefaultDeviceID()
        } else if let device = availableDevices.first(where: { $0.uid == currentDeviceUID }) {
            return device.id
        } else {
            return AudioDeviceManager.getDefaultDeviceID()
        }
    }

    private func applyOutputDevice() {
        guard let audioUnit = engine.outputNode.audioUnit else { return }

        var id = currentOutputDeviceID()
        AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &id,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
    }

    /// Match device sample rate (and optionally bit depth) to the file being played.
    /// In exclusive mode, also takes hog mode for bit-perfect output.
    private func applyBitPerfectSettings(for format: AVAudioFormat) {
        let deviceID = currentOutputDeviceID()
        let fileSampleRate = format.sampleRate

        // Save original device state (sample rate) before modifying
        if savedDeviceState == nil || savedDeviceState?.deviceID != deviceID {
            let device = availableDevices.first(where: { $0.id == deviceID })
            savedDeviceState = (deviceID: deviceID, sampleRate: device?.sampleRate ?? 44100)
        }

        // Switch sample rate to match the file
        AudioDeviceManager.setSampleRate(fileSampleRate, deviceID: deviceID)

        // Exclusive mode: hog + physical format matching
        if exclusiveModeEnabled {
            // If hogged on a different device, release first
            if let hogged = hoggedDeviceID, hogged != deviceID {
                AudioDeviceManager.releaseHogMode(hogged)
                hoggedDeviceID = nil
            }
            if hoggedDeviceID == nil {
                if AudioDeviceManager.setHogMode(deviceID) {
                    hoggedDeviceID = deviceID
                }
            }
            let bitDepth = UInt32(format.streamDescription.pointee.mBitsPerChannel)
            if bitDepth > 0 {
                AudioDeviceManager.setPhysicalFormat(
                    deviceID: deviceID,
                    sampleRate: fileSampleRate,
                    bitsPerChannel: bitDepth
                )
            }
        }
    }

    /// Restore device settings (sample rate, hog mode) on stop
    private func restoreDeviceSettings() {
        // Restore sample rate on the device we modified (not current, which may have changed)
        if let saved = savedDeviceState {
            AudioDeviceManager.setSampleRate(saved.sampleRate, deviceID: saved.deviceID)
            savedDeviceState = nil
        }
        // Release hog on the device we hogged (tracked by ID)
        if let hogged = hoggedDeviceID {
            AudioDeviceManager.releaseHogMode(hogged)
            hoggedDeviceID = nil
        }
    }

    /// Called on app termination to ensure device cleanup
    func cleanupBeforeQuit() {
        restoreDeviceSettings()
    }
    #endif

    // MARK: - EQ

    func applyEQPreset(_ preset: HeadphonePreset) {
        eqNode.globalGain = Float(preset.preamp)
        for band in eqNode.bands { band.bypass = true }
        for (i, presetBand) in preset.bands.prefix(eqNode.bands.count).enumerated() {
            let band = eqNode.bands[i]
            band.bypass = false
            band.frequency = Float(presetBand.frequency)
            band.gain = Float(presetBand.gain)
            band.bandwidth = Float(qToBandwidth(presetBand.q))
            switch presetBand.type {
            case .peak: band.filterType = .parametric
            case .lowShelf: band.filterType = .lowShelf
            case .highShelf: band.filterType = .highShelf
            }
        }
    }

    func setEQEnabled(_ enabled: Bool) {
        eqNode.bypass = !enabled
    }

    private func qToBandwidth(_ q: Double) -> Double {
        2.0 * asinh(1.0 / (2.0 * q)) / log(2.0)
    }

    private func connectNodes(format: AVAudioFormat) {
        engine.disconnectNodeOutput(playerNode)
        engine.disconnectNodeOutput(eqNode)
        engine.connect(playerNode, to: eqNode, format: format)
        engine.connect(eqNode, to: engine.mainMixerNode, format: format)
    }

    // MARK: - Playback

    func playTrack(_ track: Track) {
        setQueue([track], startIndex: 0)
    }

    func playAlbum(_ tracks: [Track], startIndex: Int = 0) {
        setQueue(tracks, startIndex: startIndex)
    }

    func playShuffled(_ tracks: [Track]) {
        var shuffled = tracks
        shuffled.shuffle()
        shuffle = true
        setQueue(shuffled, startIndex: 0)
    }

    func toggleShuffle() {
        shuffle.toggle()
        if shuffle && !queue.isEmpty && queueIndex >= 0 && queueIndex < queue.count {
            originalQueue = queue
            var remaining = Array(queue[(queueIndex + 1)...])
            remaining.shuffle()
            queue = Array(queue[...queueIndex]) + remaining
        } else if !shuffle && !originalQueue.isEmpty {
            if let current = currentTrack,
               let newIndex = originalQueue.firstIndex(where: { $0.path == current.path }) {
                queue = originalQueue
                queueIndex = newIndex
            }
            originalQueue = []
        }
        // Queue changed: invalidate gapless pre-scheduled track
        invalidateGapless()
    }

    func toggleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    func setQueue(_ tracks: [Track], startIndex: Int = 0) {
        queue = tracks
        originalQueue = shuffle ? tracks : []
        queueIndex = startIndex
        if queueIndex < queue.count {
            currentTrack = queue[queueIndex]
            playFile(queue[queueIndex].path)
        }
    }

    private func playFile(_ path: String) {
        stopPlayback()
        playbackGeneration += 1
        let gen = playbackGeneration
        let url: URL
        #if os(iOS)
        url = resolveSecurityScopedURL(for: path)
        #else
        url = URL(fileURLWithPath: path)
        #endif
        do {
            audioFile = try AVAudioFile(forReading: url)
            guard let file = audioFile else { return }

            connectNodes(format: file.processingFormat)
            #if os(macOS)
            applyOutputDevice()
            applyBitPerfectSettings(for: file.processingFormat)
            #endif
            try engine.start()

            playerNode.volume = effectiveVolume()
            seekOffset = 0
            playerNode.scheduleFile(file, at: nil) { [weak self] in
                Task { @MainActor in
                    guard let self, gen == self.playbackGeneration else { return }
                    self.trackDidEnd()
                }
            }

            // Pre-schedule next track for gapless playback
            if gaplessEnabled {
                preScheduleNextTrack(afterFormat: file.processingFormat, generation: gen)
            }

            playerNode.play()

            duration = Double(file.length) / file.processingFormat.sampleRate
            state = .playing
            startPositionTimer()
            syncWidgetState()
        } catch {
            #if os(iOS)
            activeSecurityScopedURL?.stopAccessingSecurityScopedResource()
            activeSecurityScopedURL = nil
            #endif
            state = .stopped
        }
    }

    /// Pre-schedule the next track on the playerNode for gapless transition.
    /// Only works if the next track has the same audio format.
    private func preScheduleNextTrack(afterFormat: AVAudioFormat, generation: Int) {
        nextAudioFile = nil
        guard repeatMode != .one else { return }
        let nextIndex = queueIndex + 1
        guard nextIndex < queue.count else { return }
        let nextTrack = queue[nextIndex]
        let nextURL: URL
        #if os(iOS)
        nextURL = resolveSecurityScopedURL(for: nextTrack.path)
        #else
        nextURL = URL(fileURLWithPath: nextTrack.path)
        #endif
        guard let nextFile = try? AVAudioFile(forReading: nextURL) else { return }
        // Only pre-schedule if formats match (same sample rate, channels, etc.)
        guard nextFile.processingFormat == afterFormat else { return }
        nextAudioFile = nextFile
        playerNode.scheduleFile(nextFile, at: nil) { [weak self] in
            Task { @MainActor in
                guard let self, generation == self.playbackGeneration else { return }
                self.gaplessNextTrackDidEnd()
            }
        }
    }

    /// Invalidate any gaplessly pre-scheduled next track.
    /// Called when queue changes, shuffle toggles, or seek occurs.
    private func invalidateGapless() {
        guard nextAudioFile != nil else { return }
        nextAudioFile = nil
        // Bump generation so the stale completion handler is ignored
        playbackGeneration += 1
        // Re-schedule current track from current position if playing
        if state == .playing || state == .paused, let file = audioFile {
            let wasPlaying = state == .playing
            playerNode.stop()
            let gen = playbackGeneration
            let currentPos = position
            seekOffset = currentPos
            let sampleRate = file.processingFormat.sampleRate
            let startFrame = AVAudioFramePosition(currentPos * sampleRate)
            let totalFrames = file.length
            guard startFrame < totalFrames else { return }
            let frameCount = AVAudioFrameCount(totalFrames - startFrame)
            playerNode.scheduleSegment(file, startingFrame: startFrame, frameCount: frameCount, at: nil) { [weak self] in
                Task { @MainActor in
                    guard let self, gen == self.playbackGeneration else { return }
                    self.trackDidEnd()
                }
            }
            // Re-schedule gapless for the new queue state
            if gaplessEnabled {
                preScheduleNextTrack(afterFormat: file.processingFormat, generation: gen)
            }
            if wasPlaying {
                playerNode.play()
            }
        }
    }

    func togglePlayPause() {
        switch state {
        case .playing:
            pause()
        case .paused:
            resume()
        case .stopped:
            if let track = currentTrack {
                playFile(track.path)
            }
        }
    }

    func pause() {
        playerNode.pause()
        state = .paused
        stopPositionTimer()
        syncWidgetState()
    }

    func resume() {
        if !engine.isRunning {
            do { try engine.start() } catch { return }
        }
        playerNode.play()
        state = .playing
        startPositionTimer()
        syncWidgetState()
    }

    func stop() {
        stopPlayback()
        state = .stopped
        position = 0
        currentTrack = nil
        queue = []
        queueIndex = -1
        syncWidgetState()
    }

    private func stopPlayback() {
        playerNode.stop()
        if engine.isRunning { engine.stop() }
        stopPositionTimer()
        nextAudioFile = nil
        #if os(macOS)
        restoreDeviceSettings()
        #elseif os(iOS)
        activeSecurityScopedURL?.stopAccessingSecurityScopedResource()
        activeSecurityScopedURL = nil
        #endif
    }

    func seek(to seconds: Double) {
        guard audioFile != nil else { return }
        let wasPlaying = state == .playing
        // Invalidate gapless state: playerNode.stop() clears all scheduled buffers
        nextAudioFile = nil
        playerNode.stop()
        playbackGeneration += 1
        schedulePlayback(from: seconds)
        if wasPlaying {
            playerNode.play()
        }
        position = seconds
    }

    private func schedulePlayback(from seconds: Double) {
        guard let file = audioFile else { return }
        let gen = playbackGeneration
        let sampleRate = file.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(seconds * sampleRate)
        let totalFrames = file.length
        guard startFrame < totalFrames else {
            // Seeking to/past end: advance to next track
            trackDidEnd()
            return
        }
        let frameCount = AVAudioFrameCount(totalFrames - startFrame)
        seekOffset = seconds
        playerNode.scheduleSegment(file, startingFrame: startFrame, frameCount: frameCount, at: nil) { [weak self] in
            Task { @MainActor in
                guard let self, gen == self.playbackGeneration else { return }
                self.trackDidEnd()
            }
        }
        // Re-schedule gapless after seek
        if gaplessEnabled {
            preScheduleNextTrack(afterFormat: file.processingFormat, generation: gen)
        }
    }

    func playNext(_ track: Track) {
        if queue.isEmpty {
            setQueue([track], startIndex: 0)
        } else {
            queue.insert(track, at: queueIndex + 1)
            if shuffle && !originalQueue.isEmpty {
                originalQueue.append(track)
            }
            invalidateGapless()
        }
    }

    func addToQueue(_ track: Track) {
        if queue.isEmpty {
            setQueue([track], startIndex: 0)
        } else {
            queue.append(track)
            if shuffle && !originalQueue.isEmpty {
                originalQueue.append(track)
            }
            // Only invalidate if the appended track is the new "next" (queue was at end)
            if queueIndex == queue.count - 2 {
                invalidateGapless()
            }
        }
    }

    func next() {
        if queueIndex < queue.count - 1 {
            queueIndex += 1
            currentTrack = queue[queueIndex]
            playFile(queue[queueIndex].path)
        } else if repeatMode == .all && !queue.isEmpty {
            queueIndex = 0
            currentTrack = queue[0]
            playFile(queue[0].path)
        }
    }

    func previous() {
        if position > 3 {
            seek(to: 0)
            return
        }
        if queueIndex > 0 {
            queueIndex -= 1
            currentTrack = queue[queueIndex]
            playFile(queue[queueIndex].path)
        }
    }

    func setVolume(_ value: Float) {
        volume = max(0, min(1, value))
        playerNode.volume = effectiveVolume()
    }

    /// Compute effective volume including ReplayGain adjustment
    private func effectiveVolume() -> Float {
        guard replayGainEnabled, let track = currentTrack else { return volume }
        let gainDB: Double
        if replayGainMode == "album", let albumGain = track.replaygainAlbumGain {
            gainDB = albumGain
        } else if let trackGain = track.replaygainTrackGain {
            gainDB = trackGain
        } else {
            return volume
        }
        // Convert dB to linear scale and clamp to [0, 1]
        let linearGain = Float(pow(10.0, gainDB / 20.0))
        return max(0, min(1, volume * linearGain))
    }

    // MARK: - Security-Scoped Access (iOS)

    #if os(iOS)
    /// Resolves a file path to a security-scoped URL by finding the matching
    /// folder URL, starting scoped access, and returning a usable URL.
    private func resolveSecurityScopedURL(for path: String) -> URL {
        // Sort by longest path first to match most specific folder
        let sorted = securityScopedFolderURLs.sorted { $0.key.count > $1.key.count }
        for (folderPath, folderURL) in sorted {
            if path.hasPrefix(folderPath) {
                // Stop previous access if different folder
                if let active = activeSecurityScopedURL, active != folderURL {
                    active.stopAccessingSecurityScopedResource()
                }
                if activeSecurityScopedURL != folderURL {
                    if folderURL.startAccessingSecurityScopedResource() {
                        activeSecurityScopedURL = folderURL
                    }
                }
                let relativePath = String(path.dropFirst(folderPath.count))
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                return folderURL.appendingPathComponent(relativePath)
            }
        }
        return URL(fileURLWithPath: path)
    }
    #endif

    // MARK: - Position Timer

    private func startPositionTimer() {
        stopPositionTimer()
        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.state == .playing else { return }

                if let nodeTime = self.playerNode.lastRenderTime,
                   let playerTime = self.playerNode.playerTime(forNodeTime: nodeTime) {
                    let pos = self.seekOffset + Double(playerTime.sampleTime) / playerTime.sampleRate
                    self.position = min(pos, self.duration)
                }
                self.widgetSyncCounter += 1
                if self.widgetSyncCounter % 20 == 0 {
                    self.syncWidgetState()
                }
            }
        }
    }

    private func stopPositionTimer() {
        positionTimer?.invalidate()
        positionTimer = nil
    }

    private func trackDidEnd() {
        guard state == .playing else { return }
        if repeatMode == .one {
            // For repeat-one, restart the current track cleanly (not seek,
            // because gapless may have queued the next track on the playerNode)
            if let track = currentTrack {
                nextAudioFile = nil
                playFile(track.path)
            }
            return
        }
        if queueIndex < queue.count - 1 {
            if gaplessEnabled, let nextFile = nextAudioFile {
                gaplessTransition(nextFile: nextFile)
            } else {
                next()
            }
        } else if repeatMode == .all && !queue.isEmpty {
            queueIndex = 0
            currentTrack = queue[0]
            playFile(queue[0].path)
        } else {
            stopPositionTimer()
            state = .stopped
            position = 0
            syncWidgetState()
        }
    }

    /// Handle gapless transition: the next file is already playing on the playerNode
    private func gaplessTransition(nextFile: AVAudioFile) {
        queueIndex += 1
        guard queueIndex < queue.count else {
            // Queue was modified; fall back to stop
            stopPositionTimer()
            state = .stopped
            position = 0
            return
        }
        currentTrack = queue[queueIndex]
        audioFile = nextFile
        nextAudioFile = nil
        seekOffset = 0
        duration = Double(nextFile.length) / nextFile.processingFormat.sampleRate
        position = 0
        playerNode.volume = effectiveVolume()
        syncWidgetState()

        // Pre-schedule the track after this one
        let gen = playbackGeneration
        preScheduleNextTrack(afterFormat: nextFile.processingFormat, generation: gen)
    }

    /// Called when a gaplessly pre-scheduled track finishes playing
    private func gaplessNextTrackDidEnd() {
        trackDidEnd()
    }

    // MARK: - Audio Session Observers (iOS)

    #if os(iOS)
    private func setupAudioSessionObservers() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil, queue: .main
        ) { [weak self] notification in
            let info = notification.userInfo
            let typeValue = info?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsValue = info?[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor in
                guard let self else { return }
                guard let typeValue, let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

                if type == .began {
                    if self.state == .playing {
                        self.pause()
                    }
                } else if type == .ended {
                    if let optionsValue {
                        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                        if options.contains(.shouldResume) {
                            self.resume()
                        }
                    }
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil, queue: .main
        ) { [weak self] notification in
            let info = notification.userInfo
            let reasonValue = info?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor in
                guard let self else { return }
                guard let reasonValue, let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

                // Pause when headphones are unplugged
                if reason == .oldDeviceUnavailable && self.state == .playing {
                    self.pause()
                }
            }
        }
    }
    #endif

    // MARK: - Widget Sync

    var isFavoriteCheck: ((Track?) -> Bool)?

    func syncWidgetState() {
        let isFav = isFavoriteCheck?(currentTrack) ?? false
        WidgetState.writeNowPlaying(
            currentTrack,
            isPlaying: state == .playing,
            progress: duration > 0 ? position / duration : 0,
            queue: queue,
            isFavorite: isFav
        )
    }

    nonisolated deinit {
        MainActor.assumeIsolated {
            positionTimer?.invalidate()
            positionTimer = nil
        }
    }
}
