import SpriteKit

/// The prism at the centre of the playfield.
///
/// Drawn from a path rather than an image so it stays crisp at any size and the jam build
/// needs no art asset.
final class PrismNode: SKNode {

    private let core: SKShapeNode
    private let glow: SKShapeNode

    init(radius: CGFloat) {
        let path = PrismNode.trianglePath(radius: radius)

        core = SKShapeNode(path: path)
        core.strokeColor = Theme.prismStroke
        core.lineWidth = 2
        core.fillColor = .clear
        core.lineJoin = .round

        glow = SKShapeNode(path: path)
        glow.strokeColor = Theme.prismStroke
        glow.lineWidth = 10
        glow.fillColor = .clear
        glow.alpha = 0.16
        glow.lineJoin = .round
        glow.blendMode = .add

        super.init()
        addChild(glow)
        addChild(core)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("PrismNode is created in code only")
    }

    /// Equilateral triangle, point up.
    private static func trianglePath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let angles: [CGFloat] = [90, 210, 330].map { $0 * .pi / 180 }
        for (index, angle) in angles.enumerated() {
            let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    /// A brief brightening, used on the downbeat.
    func pulse(allowed: Bool) {
        guard allowed else { return }
        glow.removeAction(forKey: "pulse")
        glow.run(
            .sequence([
                .fadeAlpha(to: 0.38, duration: 0.05),
                .fadeAlpha(to: 0.16, duration: 0.25)
            ]),
            withKey: "pulse"
        )
    }
}
