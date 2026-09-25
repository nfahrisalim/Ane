import Testing
import Foundation
@testable import RhythmKit

@Suite("Layout")
struct LayoutTests {

    private let layout = Layout.standard

    @Test("beams sit 120 degrees apart")
    func beamSpacing() {
        #expect(abs(BeamColor.magenta.beamOffset) < 1e-12)
        #expect(abs(AngleMath.degrees(radians: BeamColor.cyan.beamOffset) - 120) < 1e-9)
        #expect(abs(AngleMath.degrees(radians: BeamColor.amber.beamOffset) - 240) < 1e-9)
    }

    @Test("four targets share three colours, so exactly one colour repeats")
    func colourLayout() {
        #expect(layout.targetCount == 4)
        #expect(Set(layout.targetColors).count == 3)
    }

    /// The load-bearing claim of the whole design. If two notes could ever be satisfied
    /// by one rotation, the player could park the prism and stop playing.
    @Test("no prism angle ever satisfies two targets at once")
    func onlyOneAlignmentAtATime() {
        var maxSimultaneous = 0
        // 0.1 degree steps through a full turn.
        for step in 0..<3600 {
            let prism = AngleMath.radians(degrees: Double(step) / 10)
            var aligned = 0
            for target in 0..<layout.targetCount {
                if layout.isAligned(prismAngle: prism, targetIndex: target, color: layout.targetColors[target]) {
                    aligned += 1
                }
            }
            maxSimultaneous = max(maxSimultaneous, aligned)
        }
        #expect(maxSimultaneous == 1)
    }

    @Test("the required prism angle does align the matching beam")
    func requiredAngleAligns() {
        for target in 0..<layout.targetCount {
            let color = layout.targetColors[target]
            let prism = layout.requiredPrismAngle(targetIndex: target, color: color)
            #expect(layout.isAligned(prismAngle: prism, targetIndex: target, color: color))
        }
    }

    @Test("the required angle keeps working after whole extra turns")
    func requiredAngleSurvivesWinding() {
        for target in 0..<layout.targetCount {
            let color = layout.targetColors[target]
            let base = layout.requiredPrismAngle(targetIndex: target, color: color)
            for turns in -3...3 {
                let prism = base + Double(turns) * AngleMath.tau
                #expect(layout.isAligned(prismAngle: prism, targetIndex: target, color: color))
            }
        }
    }

    @Test("adjacent demands are at least 30 degrees apart")
    func demandsAreFarApart() {
        let required = (0..<layout.targetCount).map {
            layout.requiredPrismAngle(targetIndex: $0, color: layout.targetColors[$0])
        }
        for i in required.indices {
            for j in required.indices where j != i {
                let gap = AngleMath.degrees(radians: AngleMath.distance(required[i], required[j]))
                #expect(gap >= 30 - 1e-9, "targets \(i) and \(j) are only \(gap) degrees apart")
            }
        }
    }

    @Test("just outside the tolerance is not aligned")
    func toleranceEdge() {
        let color = layout.targetColors[0]
        let prism = layout.requiredPrismAngle(targetIndex: 0, color: color)
        let justInside = prism + AngleMath.radians(degrees: 11.9)
        let justOutside = prism + AngleMath.radians(degrees: 12.1)
        #expect(layout.isAligned(prismAngle: justInside, targetIndex: 0, color: color))
        #expect(!layout.isAligned(prismAngle: justOutside, targetIndex: 0, color: color))
    }

    @Test("a beam of the wrong colour does not count")
    func wrongColourDoesNotScore() {
        // Target 0 is magenta; park the cyan beam on it and it must still read unaligned
        // for a magenta note.
        let prism = layout.requiredPrismAngle(targetIndex: 0, color: .cyan)
        #expect(layout.isAligned(prismAngle: prism, targetIndex: 0, color: .cyan))
        #expect(!layout.isAligned(prismAngle: prism, targetIndex: 0, color: .magenta))
    }
}
