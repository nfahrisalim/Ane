import Foundation

/// A single demand from the chart: on `beatIndex`, the `color` beam must point at `targetIndex`.
public struct Note: Equatable, Hashable, Sendable {
    public let beatIndex: Int
    public let targetIndex: Int
    public let color: BeamColor

    public init(beatIndex: Int, targetIndex: Int, color: BeamColor) {
        self.beatIndex = beatIndex
        self.targetIndex = targetIndex
        self.color = color
    }
}

/// An immutable, fully-resolved song plan. Times are derived from the beat grid only,
/// never accumulated, so a chart cannot drift no matter how long the song runs.
public struct Chart: Sendable {

    public let bpm: Double
    /// Offset of beat 0 within the audio file, in seconds.
    public let firstBeatOffset: Double
    /// Total beats in the song, including the empty outro.
    public let totalBeats: Int
    public let notes: [Note]
    public let layout: Layout

    public init(bpm: Double, firstBeatOffset: Double, totalBeats: Int, notes: [Note], layout: Layout) {
        self.bpm = bpm
        self.firstBeatOffset = firstBeatOffset
        self.totalBeats = totalBeats
        self.notes = notes
        self.layout = layout
    }

    public var beatDuration: Double { 60.0 / bpm }

    public func beatTime(_ beatIndex: Int) -> Double {
        firstBeatOffset + Double(beatIndex) * beatDuration
    }

    /// Time of the note at `noteIndex`.
    public func time(of noteIndex: Int) -> Double {
        beatTime(notes[noteIndex].beatIndex)
    }

    /// Wall-clock length of the playable song, outro included.
    public var duration: Double { beatTime(totalBeats) }
}
