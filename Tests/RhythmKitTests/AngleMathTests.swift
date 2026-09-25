import Testing
import Foundation
@testable import RhythmKit

@Suite("AngleMath")
struct AngleMathTests {

    private let epsilon = 1e-9

    @Test("no difference between identical angles")
    func identity() {
        #expect(abs(AngleMath.shortestDelta(1.2, 1.2)) < epsilon)
    }

    @Test("full turns collapse to zero")
    func fullTurns() {
        #expect(abs(AngleMath.shortestDelta(0, AngleMath.tau)) < epsilon)
        #expect(abs(AngleMath.shortestDelta(0, 4 * .pi)) < epsilon)
        #expect(abs(AngleMath.shortestDelta(0.7, 0.7 - AngleMath.tau)) < epsilon)
    }

    @Test("crossing the seam takes the short way")
    func seam() {
        // Just below +pi to just above -pi is 0.2 rad apart, not tau - 0.2.
        let from = Double.pi - 0.1
        let to = -Double.pi + 0.1
        let d = AngleMath.shortestDelta(from, to)
        #expect(abs(d - 0.2) < 1e-9)
    }

    @Test("half turns resolve to +pi, never -pi")
    func halfTurns() {
        #expect(abs(AngleMath.shortestDelta(0, .pi) - .pi) < epsilon)
        #expect(abs(AngleMath.shortestDelta(0, -.pi) - .pi) < epsilon)
    }

    @Test("negative and unbounded angles behave")
    func negatives() {
        #expect(abs(AngleMath.shortestDelta(-3 * .pi, 0) - .pi) < epsilon)
        #expect(abs(AngleMath.shortestDelta(-0.2, 0.2) - 0.4) < epsilon)
        #expect(abs(AngleMath.shortestDelta(10 * .pi + 0.3, 0.3)) < 1e-9)
    }

    @Test("delta stays inside (-pi, pi] for a sweep of inputs")
    func rangeInvariant() {
        for i in -400...400 {
            let from = Double(i) * 0.37
            for j in -50...50 {
                let to = Double(j) * 0.91
                let d = AngleMath.shortestDelta(from, to)
                #expect(d > -Double.pi - epsilon)
                #expect(d <= Double.pi + epsilon)
            }
        }
    }

    @Test("distance is symmetric and never negative")
    func distanceSymmetry() {
        #expect(abs(AngleMath.distance(0.4, 2.9) - AngleMath.distance(2.9, 0.4)) < epsilon)
        #expect(AngleMath.distance(-2.0, 2.0) >= 0)
        #expect(AngleMath.distance(-2.0, 2.0) <= Double.pi + epsilon)
    }

    @Test("normalized lands in [0, tau)")
    func normalize() {
        #expect(abs(AngleMath.normalized(-0.5) - (AngleMath.tau - 0.5)) < 1e-9)
        #expect(AngleMath.normalized(AngleMath.tau) < 1e-9)
        for i in -100...100 {
            let n = AngleMath.normalized(Double(i) * 1.7)
            #expect(n >= 0)
            #expect(n < AngleMath.tau)
        }
    }

    @Test("degree conversion round-trips")
    func degrees() {
        #expect(abs(AngleMath.radians(degrees: 180) - .pi) < epsilon)
        #expect(abs(AngleMath.degrees(radians: .pi) - 180) < 1e-9)
    }
}
