import AVFoundation
import AudioToolbox
import CoreAudio

final class AudioEngine {

    // MARK: - Nodes
    private let engine       = AVAudioEngine()
    private let player       = AVAudioPlayerNode()
    private let preampMixer  = AVAudioMixerNode()
    private let reverbEffect : AVAudioUnitEffect
    private let eqNode       : AVAudioUnitEQ
    private let distNode     : AVAudioUnitDistortion
    private let dynNode      : AVAudioUnitEffect
    private let tapMixer     = AVAudioMixerNode()

    // MARK: - Tap output
    var onSamples: (([Float]) -> Void)?

    // MARK: - Track completion
    var onTrackEnded: (() -> Void)?

    // MARK: - Internal state
    private var currentFile: AVAudioFile?
    private(set) var duration: Double = 0
    private var scheduledStartSample: AVAudioFramePosition = 0

    // MARK: - Init

    init() {
        let rev2 = AudioComponentDescription(
            componentType:         kAudioUnitType_Effect,
            componentSubType:      kAudioUnitSubType_Reverb2,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0, componentFlagsMask: 0)
        reverbEffect = AVAudioUnitEffect(audioComponentDescription: rev2)

        eqNode = AVAudioUnitEQ(numberOfBands: 1)
        let b = eqNode.bands[0]
        b.filterType  = .parametric
        b.frequency   = 150
        b.bandwidth   = 2.0    // ~Q 0.5, wide bell
        b.gain        = 0
        b.bypass      = false

        distNode = AVAudioUnitDistortion()
        distNode.loadFactoryPreset(.softDistortionFullWave)
        distNode.preGain    = 0
        distNode.wetDryMix  = 0

        let dynDesc = AudioComponentDescription(
            componentType:         kAudioUnitType_Dynamics,
            componentSubType:      kAudioUnitSubType_DynamicsProcessor,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0, componentFlagsMask: 0)
        dynNode = AVAudioUnitEffect(audioComponentDescription: dynDesc)

        buildGraph()
        setLowLatency()
        applyLimiterMode()
    }

    // MARK: - Graph setup

    private func buildGraph() {
        for n in [player, preampMixer, reverbEffect, eqNode, distNode, dynNode, tapMixer] as [AVAudioNode] {
            engine.attach(n)
        }
        engine.connect(player,       to: preampMixer,  format: nil)
        engine.connect(preampMixer,  to: reverbEffect, format: nil)
        engine.connect(reverbEffect, to: eqNode,       format: nil)
        engine.connect(eqNode,       to: distNode,     format: nil)
        engine.connect(distNode,     to: dynNode,      format: nil)
        engine.connect(dynNode,      to: tapMixer,     format: nil)
        engine.connect(tapMixer,     to: engine.mainMixerNode, format: nil)

        tapMixer.installTap(onBus: 0, bufferSize: 512, format: nil) { [weak self] buf, _ in
            guard let ch = buf.floatChannelData else { return }
            let n = min(Int(buf.frameLength), 256)
            let samples = (0..<n).map { ch[0][$0] }
            self?.onSamples?(samples)
        }

        try? engine.start()
    }

    private func setLowLatency() {
        var devID = AudioDeviceID(kAudioObjectUnknown)
        var sz    = UInt32(MemoryLayout<AudioDeviceID>.size)
        var prop  = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope:    kAudioObjectPropertyScopeGlobal,
            mElement:  kAudioObjectPropertyElementMain)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &prop, 0, nil, &sz, &devID)
        guard devID != kAudioObjectUnknown else { return }
        var frames: UInt32 = 256
        prop.mSelector = kAudioDevicePropertyBufferFrameSize
        AudioObjectSetPropertyData(devID, &prop, 0, nil, UInt32(MemoryLayout<UInt32>.size), &frames)
    }

    // MARK: - DSP setters

    /// Pre-amp: -12 dB to 0 dB
    func setPreamp(db: Float) {
        preampMixer.outputVolume = pow(10, db / 20)
    }

    /// Reverb: effective 0–1 (already squared by caller).
    /// Decay capped at 20 s (hardware limit of Reverb2).
    func setReverb(effective eff: Float, skipUpdate: Bool = false) {
        guard !skipUpdate else { return }
        let au    = reverbEffect.audioUnit
        let decay = max(0.001, eff * 20)
        let wet   = eff < 0.01 ? Float(0) : min(80, eff * 90)
        AudioUnitSetParameter(au, kReverb2Param_DryWetMix,          kAudioUnitScope_Global, 0, wet,          0)
        AudioUnitSetParameter(au, kReverb2Param_DecayTimeAt0Hz,     kAudioUnitScope_Global, 0, decay,        0)
        AudioUnitSetParameter(au, kReverb2Param_DecayTimeAtNyquist, kAudioUnitScope_Global, 0, decay * 0.5,  0)
        AudioUnitSetParameter(au, kReverb2Param_MinDelayTime,       kAudioUnitScope_Global, 0, 0.01,         0)
        AudioUnitSetParameter(au, kReverb2Param_MaxDelayTime,       kAudioUnitScope_Global, 0, min(1, decay), 0)
    }

    /// EQ: 0–12 dB
    func setEQ(gainDb: Float) {
        eqNode.bands[0].gain = gainDb
    }

    /// Saturator: 0–8 dB drive
    func setSaturator(driveDb: Float) {
        distNode.preGain   = driveDb
        distNode.wetDryMix = driveDb < 0.05 ? 0 : 100
    }

    enum DynamicsMode { case limiter, compressor }

    func setDynamics(mode: DynamicsMode) {
        // kDynamicsProcessorParam_Threshold=0, HeadRoom=1, AttackTime=4, ReleaseTime=5, MasterGain=6
        let au = dynNode.audioUnit
        switch mode {
        case .limiter:
            AudioUnitSetParameter(au, 0, kAudioUnitScope_Global, 0, -1,   0)  // threshold
            AudioUnitSetParameter(au, 1, kAudioUnitScope_Global, 0, 40,   0)  // headroom
            AudioUnitSetParameter(au, 4, kAudioUnitScope_Global, 0, 0.001,0)  // attack
            AudioUnitSetParameter(au, 5, kAudioUnitScope_Global, 0, 0.05, 0)  // release
            AudioUnitSetParameter(au, 6, kAudioUnitScope_Global, 0, 0,    0)  // master gain
        case .compressor:
            AudioUnitSetParameter(au, 0, kAudioUnitScope_Global, 0, -18,  0)
            AudioUnitSetParameter(au, 1, kAudioUnitScope_Global, 0, 10,   0)
            AudioUnitSetParameter(au, 4, kAudioUnitScope_Global, 0, 0.01, 0)
            AudioUnitSetParameter(au, 5, kAudioUnitScope_Global, 0, 0.25, 0)
            AudioUnitSetParameter(au, 6, kAudioUnitScope_Global, 0, 6,    0)
        }
    }

    private func applyLimiterMode() { setDynamics(mode: .limiter) }

    // MARK: - System audio capture

    private(set) var isSystemCapture = false

    /// All audio input devices (name, id). Typically includes BlackHole when installed.
    func listInputDevices() -> [(id: AudioDeviceID, name: String)] {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope:    kAudioObjectPropertyScopeGlobal,
            mElement:  0)
        var sz: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &sz) == noErr else { return [] }
        let count = Int(sz) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &sz, &ids) == noErr else { return [] }

        return ids.compactMap { devID -> (id: AudioDeviceID, name: String)? in
            // Only include devices with input channels
            var inAddr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration,
                                                    mScope: kAudioDevicePropertyScopeInput, mElement: 0)
            var inSz: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(devID, &inAddr, 0, nil, &inSz) == noErr, inSz > 0 else { return nil }
            let rawPtr = UnsafeMutableRawPointer.allocate(byteCount: Int(inSz), alignment: MemoryLayout<AudioBufferList>.alignment)
            defer { rawPtr.deallocate() }
            guard AudioObjectGetPropertyData(devID, &inAddr, 0, nil, &inSz, rawPtr) == noErr else { return nil }
            guard rawPtr.assumingMemoryBound(to: AudioBufferList.self).pointee.mNumberBuffers > 0 else { return nil }

            var nameAddr = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName,
                                                      mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
            var cfRef: Unmanaged<CFString>? = nil
            var nameSz = UInt32(MemoryLayout<Unmanaged<CFString>>.size)
            guard withUnsafeMutablePointer(to: &cfRef, { ptr in
                AudioObjectGetPropertyData(devID, &nameAddr, 0, nil, &nameSz, ptr)
            }) == noErr, let name = cfRef?.takeRetainedValue() else { return nil }
            return (id: devID, name: name as String)
        }
    }

    /// Route system audio through the DSP chain. Set macOS output to BlackHole first.
    func startSystemCapture(deviceID: AudioDeviceID) throws {
        player.stop()
        engine.stop()
        engine.disconnectNodeOutput(player)

        var dev = deviceID
        let status = AudioUnitSetProperty(
            engine.inputNode.audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global, 0,
            &dev, UInt32(MemoryLayout<AudioDeviceID>.size))
        guard status == noErr else {
            // Restore player connection before throwing
            engine.connect(player, to: preampMixer, format: nil)
            throw NSError(domain: "AudioEngine", code: Int(status),
                          userInfo: [NSLocalizedDescriptionKey: "Could not set input device (err \(status))"])
        }

        engine.connect(engine.inputNode, to: preampMixer, format: nil)
        isSystemCapture = true
        try engine.start()
    }

    func stopSystemCapture() {
        guard isSystemCapture else { return }
        engine.stop()
        engine.disconnectNodeOutput(engine.inputNode)
        engine.connect(player, to: preampMixer, format: nil)
        isSystemCapture = false
    }

    // MARK: - Playback

    func load(url: URL) throws {
        let file = try AVAudioFile(forReading: url)
        currentFile = file
        duration    = Double(file.length) / file.processingFormat.sampleRate
        player.stop()
        schedule(file: file, from: 0)
        if !engine.isRunning { try engine.start() }
    }

    private func schedule(file: AVAudioFile, from startFrame: AVAudioFramePosition) {
        scheduledStartSample = startFrame
        let remaining = AVAudioFrameCount(file.length - startFrame)
        guard remaining > 0 else { return }
        player.scheduleSegment(file, startingFrame: startFrame, frameCount: remaining, at: nil) { [weak self] in
            DispatchQueue.main.async { self?.onTrackEnded?() }
        }
    }

    func play()  { player.play() }
    func pause() { player.pause() }
    func stop()  { player.stop() }

    var isPlaying: Bool { player.isPlaying }

    var currentTime: Double {
        guard let nodeTime   = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: nodeTime),
              let file       = currentFile else { return 0 }
        let s = Double(playerTime.sampleTime) / file.processingFormat.sampleRate
        return max(0, s)
    }
}
