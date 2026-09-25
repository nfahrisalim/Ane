import Foundation

/// Deterministic 64-bit PRNG (SplitMix64).
///
/// `SystemRandomNumberGenerator` cannot be seeded, and a chart that changes between runs
/// is neither testable nor fair to retry against a best score.
public struct SeededGenerator: RandomNumberGenerator {

    private var state: UInt64

    public init(seed: UInt64) {
        // Seed 0 would make SplitMix64 start on a known-weak state.
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    public mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// Builds a chart procedurally, so no hand-charting is needed.
public struct ChartGenerator {

    public struct Config: Sendable {
        public var bpm: Double = 120
        public var firstBeatOffset: Double = 0
        /// 2 minutes at 120 BPM.
        public var totalBeats: Int = 240
        /// Silent beats before the first note, so the player can read the first telegraph.
        public var leadInBeats: Int = 8
        /// Length of the sparse opening, in beats.
        public var warmUpBeats: Int = 16
        /// One note every this many beats during the warm-up.
        public var warmUpStride: Int = 2
        /// Silent beats at the end, for the outro.
        public var outroBeats: Int = 4
        /// Hard cap on how many times one target may be asked for consecutively.
        public var maxTargetRun: Int = 2
        /// Note density for each phrase of the song, in order. When set, it replaces the
        /// fixed warm-up-then-every-beat shape, so a chart can breathe with its track:
        /// quiet in the intro, busy in the drop, empty in a breakdown.
        public var sections: [Density]?
        /// Length of one entry in `sections`, in beats. 16 is four bars of 4/4.
        public var phraseBeats: Int = 16

        public init() {}
    }

    public let config: Config
    public let layout: Layout

    public init(config: Config = Config(), layout: Layout = .standard) {
        self.config = config
        self.layout = layout
    }

    public func makeChart(seed: UInt64) -> Chart {
        var rng = SeededGenerator(seed: seed)
        var notes: [Note] = []

        let lastNoteBeat = config.totalBeats - config.outroBeats - 1
        let warmUpEnd = config.leadInBeats + config.warmUpBeats

        var previousTarget = -1
        var runLength = 0

        func place(at beat: Int) {
            let target = pickTarget(
                avoiding: previousTarget,
                runLength: runLength,
                using: &rng
            )

            notes.append(
                Note(beatIndex: beat, targetIndex: target, color: layout.targetColors[target])
            )

            if target == previousTarget {
                runLength += 1
            } else {
                previousTarget = target
                runLength = 1
            }
        }

        if let sections = config.sections, !sections.isEmpty {
            // Follow the track: each phrase sets its own density.
            guard config.leadInBeats <= lastNoteBeat else {
                return makeChart(notes: notes)
            }
            for beat in config.leadInBeats...lastNoteBeat {
                if density(at: beat, in: sections).includes(beat: beat) {
                    place(at: beat)
                }
            }
        } else {
            var beat = config.leadInBeats
            while beat <= lastNoteBeat {
                place(at: beat)
                // Sparse while the player finds the controls, then one note per beat.
                beat += beat < warmUpEnd ? config.warmUpStride : 1
            }
        }

        return makeChart(notes: notes)
    }

    private func makeChart(notes: [Note]) -> Chart {
        Chart(
            bpm: config.bpm,
            firstBeatOffset: config.firstBeatOffset,
            totalBeats: config.totalBeats,
            notes: notes,
            layout: layout
        )
    }

    /// The density governing `beat`. Beats past the last listed phrase keep its density,
    /// so a section list that is a little short never silently drops the ending.
    private func density(at beat: Int, in sections: [Density]) -> Density {
        let phrase = beat / max(config.phraseBeats, 1)
        return sections[min(phrase, sections.count - 1)]
    }

    /// Picks a target, refusing to extend a run past `maxTargetRun`.
    ///
    /// Short runs are kept on purpose: repeating a target reads as a held note, which is
    /// the only moment the player gets to stop rotating.
    private func pickTarget(
        avoiding previous: Int,
        runLength: Int,
        using rng: inout SeededGenerator
    ) -> Int {
        let runExhausted = previous >= 0 && runLength >= config.maxTargetRun
        let candidates = (0..<layout.targetCount).filter { !runExhausted || $0 != previous }
        return candidates[Int(rng.next() % UInt64(candidates.count))]
    }
}
