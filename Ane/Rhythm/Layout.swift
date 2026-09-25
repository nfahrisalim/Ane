import Foundation

/// One of the prism's three emitted beams. The raw value is also the beam's index,
/// and each beam is locked 120 degrees from the next.
public enum BeamColor: Int, CaseIterable, Hashable, Sendable {
    case magenta = 0
    case cyan = 1
    case amber = 2

    /// Offset from the prism's own rotation, in radians.
    public var beamOffset: Double {
        Double(rawValue) * (AngleMath.tau / 3)
    }

    public var displayName: String {
        switch self {
        case .magenta: return "Magenta"
        case .cyan: return "Cyan"
        case .amber: return "Amber"
        }
    }
}

/// Fixed geometry of the playfield.
///
/// The asymmetry is the whole game: beams sit 120 degrees apart, targets 90 degrees
/// apart, so no single prism rotation can ever line two beams up on two targets.
/// Every note therefore demands a real rotation.
public struct Layout: Sendable {

    /// Target angles in radians, counter-clockwise from +x.
    public let targetAngles: [Double]

    /// Colour of each target, indexed the same as `targetAngles`.
    /// Four targets share three colours, so exactly one colour repeats.
    public let targetColors: [BeamColor]

    /// Maximum angular error still counted as aligned.
    public let alignmentTolerance: Double

    public init(targetAngles: [Double], targetColors: [BeamColor], alignmentTolerance: Double) {
        precondition(targetAngles.count == targetColors.count, "every target needs a colour")
        self.targetAngles = targetAngles
        self.targetColors = targetColors
        self.alignmentTolerance = alignmentTolerance
    }

    public static let standard = Layout(
        targetAngles: [45, 135, 225, 315].map { AngleMath.radians(degrees: $0) },
        targetColors: [.magenta, .cyan, .amber, .cyan],
        alignmentTolerance: AngleMath.radians(degrees: 12)
    )

    public var targetCount: Int { targetAngles.count }

    /// World angle of a beam once the prism has rotated by `prismAngle`.
    public func beamAngle(_ color: BeamColor, prismAngle: Double) -> Double {
        prismAngle + color.beamOffset
    }

    /// Prism rotation that puts `color`'s beam exactly on `targetIndex`.
    ///
    /// Because the beams are 120 degrees apart and the targets 90, this mapping is
    /// injective: every (target, colour) pair needs its own distinct prism angle, and the
    /// closest two are 30 degrees apart -- comfortably more than twice the 12 degree
    /// tolerance, so two notes can never be satisfied by one rotation.
    public func requiredPrismAngle(targetIndex: Int, color: BeamColor) -> Double {
        AngleMath.normalized(targetAngles[targetIndex] - color.beamOffset)
    }

    /// Prism rotation that satisfies `note`.
    public func requiredPrismAngle(for note: Note) -> Double {
        requiredPrismAngle(targetIndex: note.targetIndex, color: note.color)
    }

    /// True when the matching-colour beam currently points at `targetIndex`.
    public func isAligned(prismAngle: Double, targetIndex: Int, color: BeamColor) -> Bool {
        let beam = beamAngle(color, prismAngle: prismAngle)
        return AngleMath.distance(beam, targetAngles[targetIndex]) <= alignmentTolerance
    }
}
