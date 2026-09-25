import SwiftUI
import SpriteKit

extension UIColor {
    /// 0xRRGGBB.
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(UIColor(hex: hex, alpha: alpha))
    }
}

/// One palette, shared by SpriteKit and SwiftUI, so the HUD and the playfield cannot drift.
enum Theme {

    static let backgroundHex: UInt32 = 0x0B0B10
    static let background = Color(hex: backgroundHex)
    static let backgroundUI = UIColor(hex: backgroundHex)

    static let prismStroke = UIColor.white
    static let pulse = UIColor.white

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.55)

    /// System tint for menus: selection, links, toggles. Cyan is the beam colour with the
    /// highest contrast against the background.
    static let accent = Color(hex: 0x2EE6FF)
    /// Raised surfaces in the menus (list rows, cards), one step up from the background.
    static let surface = Color(hex: 0x17171F)
    static let surfaceSelected = Color(hex: 0x22222D)

    /// Idle alpha of a target that is not currently being asked for.
    static let idleTargetAlpha: CGFloat = 0.35

    static func uiColor(for beam: BeamColor) -> UIColor {
        switch beam {
        case .magenta: return UIColor(hex: 0xFF3DCB)
        case .cyan: return UIColor(hex: 0x2EE6FF)
        case .amber: return UIColor(hex: 0xFFB02E)
        }
    }

    static func color(for beam: BeamColor) -> Color {
        Color(uiColor(for: beam))
    }
}

extension BeamColor {
    var uiColor: UIColor { Theme.uiColor(for: self) }
    var color: Color { Theme.color(for: self) }
}

/// Reduce Motion is read once per scene build rather than per frame; it cannot change
/// mid-run without the app being backgrounded, and per-frame accessibility lookups show up
/// in a profile.
struct MotionSettings {
    let isReduced: Bool

    static var current: MotionSettings {
        MotionSettings(isReduced: UIAccessibility.isReduceMotionEnabled)
    }

    var particleCountScale: CGFloat { isReduced ? 0.25 : 1.0 }
    var allowsScalePulse: Bool { !isReduced }
    var allowsBackgroundMotion: Bool { !isReduced }
}
