import SwiftUI

/// Panel chrome for the HUD and the results card.
///
/// Liquid Glass when the SDK and the device offer it, `.ultraThinMaterial` otherwise, so
/// the same call site works from iOS 17 up.
struct GlassPanel: ViewModifier {

    var cornerRadius: CGFloat = 18

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(in: .rect(cornerRadius: cornerRadius))
        } else {
            content.background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        }
    }
}

extension View {
    func glassPanel(cornerRadius: CGFloat = 18) -> some View {
        modifier(GlassPanel(cornerRadius: cornerRadius))
    }
}
