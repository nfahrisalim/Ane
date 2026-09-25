import Foundation

/// Angle helpers shared by input smoothing, beam alignment and haptic ticks.
///
/// Everything here works in `Double` radians and deliberately avoids CoreGraphics,
/// SpriteKit and UIKit so the rules can be unit-tested on the host machine.
public enum AngleMath {

    public static let tau = 2 * Double.pi

    /// Wrapped signed difference in (-pi, pi].
    ///
    /// Signed, so it can drive easing toward a target angle across the +/-pi seam
    /// without the display angle ever taking the long way around.
    public static func shortestDelta(_ from: Double, _ to: Double) -> Double {
        var d = (to - from).truncatingRemainder(dividingBy: tau)
        if d > .pi { d -= tau }
        if d <= -.pi { d += tau }
        return d
    }

    /// Absolute wrapped distance in [0, pi]. This is what "aligned" is measured with.
    public static func distance(_ a: Double, _ b: Double) -> Double {
        abs(shortestDelta(a, b))
    }

    /// Normalizes any angle into [0, tau).
    public static func normalized(_ angle: Double) -> Double {
        let r = angle.truncatingRemainder(dividingBy: tau)
        return r < 0 ? r + tau : r
    }

    public static func radians(degrees: Double) -> Double { degrees * .pi / 180 }

    public static func degrees(radians: Double) -> Double { radians * 180 / .pi }
}
