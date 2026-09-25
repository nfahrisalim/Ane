import AVFoundation

/// Synthesises a 120 BPM, 8-bar loop as four separate stems.
///
/// This exists so the whole game -- including the stem layering that is its payoff --
/// is playable and testable before any music arrives. Because it renders into ordinary
/// PCM buffers played by `AVAudioPlayerNode`, the audio clock in `AudioEngine` has
/// exactly one code path whether the stems are synthesised or loaded from files. An
/// `AVAudioSourceNode` would have forced a second, untested clock.
///
/// Deterministic: the noise is seeded, so every launch renders an identical track and a
/// screen recording can be repeated.
struct ProceduralTrack {

    let sampleRate: Double
    let bpm: Double
    let bars: Int
    let beatsPerBar: Int

    init(sampleRate: Double = 44_100, bpm: Double = 120, bars: Int = 8, beatsPerBar: Int = 4) {
        self.sampleRate = sampleRate
        self.bpm = bpm
        self.bars = bars
        self.beatsPerBar = beatsPerBar
    }

    var beatDuration: Double { 60.0 / bpm }
    var totalBeats: Int { bars * beatsPerBar }
    var duration: Double { Double(totalBeats) * beatDuration }
    var frameCount: Int { Int(duration * sampleRate) }

    // A minor: i - VI - III - VII, two bars each. Simple, and it loops without a seam.
    private let bassRoots: [Double] = [110.00, 87.31, 130.81, 98.00]
    private let padVoicings: [[Double]] = [
        [220.00, 261.63, 329.63],   // Am
        [174.61, 220.00, 261.63],   // F
        [261.63, 329.63, 392.00],   // C
        [196.00, 246.94, 293.66]    // G
    ]
    private let leadArps: [[Double]] = [
        [440.00, 523.25, 659.25, 523.25],
        [349.23, 440.00, 523.25, 440.00],
        [523.25, 659.25, 783.99, 659.25],
        [392.00, 493.88, 587.33, 493.88]
    ]

    // MARK: - Rendering

    func makeBuffers(format: AVAudioFormat) -> [StemKind: AVAudioPCMBuffer] {
        var result: [StemKind: AVAudioPCMBuffer] = [:]
        for kind in StemKind.allCases {
            guard let buffer = makeBuffer(kind, format: format) else { continue }
            result[kind] = buffer
        }
        return result
    }

    private func makeBuffer(_ kind: StemKind, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        var samples = render(kind)
        normalize(&samples, to: 0.82)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channels = buffer.floatChannelData else { return nil }

        buffer.frameLength = AVAudioFrameCount(samples.count)
        for channel in 0..<Int(format.channelCount) {
            let destination = channels[channel]
            for frame in 0..<samples.count {
                destination[frame] = samples[frame]
            }
        }
        return buffer
    }

    private func render(_ kind: StemKind) -> [Float] {
        var samples = [Float](repeating: 0, count: frameCount)
        switch kind {
        case .drums: renderDrums(into: &samples)
        case .bass: renderBass(into: &samples)
        case .synth: renderPad(into: &samples)
        case .lead: renderLead(into: &samples)
        }
        return samples
    }

    /// Index of the current chord, given a bar.
    private func chordIndex(bar: Int) -> Int {
        (bar / 2) % bassRoots.count
    }

    // MARK: - Voices

    private func renderDrums(into samples: inout [Float]) {
        var rng = SeededGenerator(seed: 0xD12D_5EED)
        for bar in 0..<bars {
            let barStart = Double(bar * beatsPerBar) * beatDuration
            // Four-on-the-floor would fight the melody; 1 and 3 leaves room.
            addKick(into: &samples, at: barStart)
            addKick(into: &samples, at: barStart + 2 * beatDuration)
            addSnare(into: &samples, at: barStart + beatDuration, rng: &rng)
            addSnare(into: &samples, at: barStart + 3 * beatDuration, rng: &rng)
            // Eighth-note hats carry the pulse between the kicks.
            for eighth in 0..<(beatsPerBar * 2) {
                let time = barStart + Double(eighth) * beatDuration / 2
                addHat(into: &samples, at: time, accent: eighth % 2 == 1, rng: &rng)
            }
            // A pickup into the next bar, so eight bars do not feel like one bar times eight.
            if bar % 4 == 3 {
                addSnare(into: &samples, at: barStart + 3.5 * beatDuration, rng: &rng)
                addSnare(into: &samples, at: barStart + 3.75 * beatDuration, rng: &rng)
            }
        }
    }

    private func renderBass(into samples: inout [Float]) {
        for bar in 0..<bars {
            let root = bassRoots[chordIndex(bar: bar)]
            let barStart = Double(bar * beatsPerBar) * beatDuration
            for eighth in 0..<(beatsPerBar * 2) {
                let time = barStart + Double(eighth) * beatDuration / 2
                // Octave on the off-beats gives it movement without a second instrument.
                let frequency = eighth % 4 == 3 ? root * 2 : root
                addSquare(
                    into: &samples,
                    frequency: frequency,
                    at: time,
                    duration: beatDuration / 2 * 0.9,
                    amplitude: 0.5,
                    decay: 0.22
                )
            }
        }
    }

    private func renderPad(into samples: inout [Float]) {
        for bar in 0..<bars {
            let voicing = padVoicings[chordIndex(bar: bar)]
            let barStart = Double(bar * beatsPerBar) * beatDuration
            let length = Double(beatsPerBar) * beatDuration
            for frequency in voicing {
                addPadTone(
                    into: &samples,
                    frequency: frequency,
                    at: barStart,
                    duration: length,
                    amplitude: 0.22
                )
            }
        }
    }

    private func renderLead(into samples: inout [Float]) {
        for bar in 0..<bars {
            let arp = leadArps[chordIndex(bar: bar)]
            let barStart = Double(bar * beatsPerBar) * beatDuration
            for eighth in 0..<(beatsPerBar * 2) {
                let time = barStart + Double(eighth) * beatDuration / 2
                let frequency = arp[eighth % arp.count]
                addTriangle(
                    into: &samples,
                    frequency: frequency,
                    at: time,
                    duration: beatDuration / 2 * 0.8,
                    amplitude: 0.32,
                    decay: 0.14
                )
            }
        }
    }

    // MARK: - Oscillators

    /// Sine with an exponential pitch drop: the cheapest convincing kick.
    private func addKick(into samples: inout [Float], at time: Double) {
        let length = 0.20
        var phase = 0.0
        forEachFrame(from: time, length: length, in: &samples) { local, value in
            let frequency = 50 + 95 * exp(-local / 0.028)
            phase += AngleMath.tau * frequency / sampleRate
            let envelope = exp(-local / 0.055)
            value += Float(sin(phase) * envelope * 0.95)
        }
    }

    private func addSnare(into samples: inout [Float], at time: Double, rng: inout SeededGenerator) {
        let length = 0.16
        var previous = 0.0
        var phase = 0.0
        forEachFrame(from: time, length: length, in: &samples) { local, value in
            let white = noise(&rng)
            // One-pole high-pass, so it cracks instead of thumping.
            let filtered = white - previous * 0.55
            previous = white
            phase += AngleMath.tau * 190 / sampleRate
            let envelope = exp(-local / 0.045)
            value += Float((filtered * 0.5 + sin(phase) * 0.25) * envelope * 0.7)
        }
    }

    private func addHat(into samples: inout [Float], at time: Double, accent: Bool, rng: inout SeededGenerator) {
        let length = 0.05
        var previous = 0.0
        let gain = accent ? 0.22 : 0.13
        forEachFrame(from: time, length: length, in: &samples) { local, value in
            let white = noise(&rng)
            // Differencing pushes the energy up where a hat lives.
            let filtered = white - previous
            previous = white
            let envelope = exp(-local / 0.011)
            value += Float(filtered * envelope * gain)
        }
    }

    private func addSquare(
        into samples: inout [Float],
        frequency: Double,
        at time: Double,
        duration: Double,
        amplitude: Double,
        decay: Double
    ) {
        var phase = 0.0
        forEachFrame(from: time, length: duration, in: &samples) { local, value in
            phase += frequency / sampleRate
            if phase >= 1 { phase -= 1 }
            let square = phase < 0.5 ? 1.0 : -1.0
            let envelope = exp(-local / decay) * attack(local, over: 0.004)
            value += Float(square * envelope * amplitude)
        }
    }

    private func addTriangle(
        into samples: inout [Float],
        frequency: Double,
        at time: Double,
        duration: Double,
        amplitude: Double,
        decay: Double
    ) {
        var phase = 0.0
        forEachFrame(from: time, length: duration, in: &samples) { local, value in
            phase += frequency / sampleRate
            if phase >= 1 { phase -= 1 }
            let triangle = 4 * abs(phase - 0.5) - 1
            let envelope = exp(-local / decay) * attack(local, over: 0.006)
            value += Float(triangle * envelope * amplitude)
        }
    }

    /// Three slightly detuned sines with a slow attack and release: a pad without a filter.
    private func addPadTone(
        into samples: inout [Float],
        frequency: Double,
        at time: Double,
        duration: Double,
        amplitude: Double
    ) {
        var phases = [0.0, 0.0, 0.0]
        let detunes = [0.997, 1.0, 1.004]
        forEachFrame(from: time, length: duration, in: &samples) { local, value in
            var sum = 0.0
            for voice in 0..<3 {
                phases[voice] += AngleMath.tau * frequency * detunes[voice] / sampleRate
                sum += sin(phases[voice])
            }
            let release = min(1.0, (duration - local) / 0.25)
            let envelope = attack(local, over: 0.12) * max(0, release)
            value += Float(sum / 3 * envelope * amplitude)
        }
    }

    // MARK: - Helpers

    /// Walks the frames a voice occupies, clipping safely at the end of the loop.
    private func forEachFrame(
        from time: Double,
        length: Double,
        in samples: inout [Float],
        body: (Double, inout Float) -> Void
    ) {
        let start = Int(time * sampleRate)
        let count = Int(length * sampleRate)
        guard start < samples.count else { return }
        for offset in 0..<count {
            let index = start + offset
            guard index < samples.count else { return }
            body(Double(offset) / sampleRate, &samples[index])
        }
    }

    private func attack(_ local: Double, over span: Double) -> Double {
        min(1.0, local / span)
    }

    /// White noise in [-1, 1] from the seeded generator.
    private func noise(_ rng: inout SeededGenerator) -> Double {
        Double(rng.next() >> 11) / Double(1 << 53) * 2 - 1
    }

    private func normalize(_ samples: inout [Float], to peak: Float) {
        var maximum: Float = 0
        for sample in samples {
            maximum = max(maximum, abs(sample))
        }
        guard maximum > 0.0001 else { return }
        let gain = peak / maximum
        for index in samples.indices {
            samples[index] *= gain
        }
    }
}
