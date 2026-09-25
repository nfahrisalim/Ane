import SpriteKit

/// One of the prism's three beams, drawn along its parent's +x axis.
///
/// The beam's own `zRotation` holds its fixed 120 degree offset, so rotating the parent
/// rotor moves all three together and the offsets can never drift apart.
final class BeamNode: SKNode {

    let beam: BeamColor

    private let core: SKShapeNode
    private let glow: SKShapeNode
    private let baseGlowAlpha: CGFloat = 0.20

    init(beam: BeamColor, length: CGFloat) {
        self.beam = beam

        let path = BeamNode.path(length: length)

        core = SKShapeNode(path: path)
        core.strokeColor = beam.uiColor
        core.lineWidth = 2.5
        core.alpha = 0.9
        core.blendMode = .add
        core.lineCap = .round

        // A wider, dimmer copy underneath reads as bloom without a shader or a blur pass.
        glow = SKShapeNode(path: path)
        glow.strokeColor = beam.uiColor
        glow.lineWidth = 14
        glow.alpha = baseGlowAlpha
        glow.blendMode = .add
        glow.lineCap = .round

        super.init()
        zRotation = CGFloat(beam.beamOffset)
        addChild(glow)
        addChild(core)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("BeamNode is created in code only")
    }

    private static func path(length: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: length, y: 0))
        return path
    }

    /// Re-cuts the beam for a new orbit radius, keeping the node and any running actions.
    func updateLength(_ length: CGFloat) {
        let path = BeamNode.path(length: length)
        core.path = path
        glow.path = path
    }

    /// Brightens this beam on a clean hit of its colour.
    func flash() {
        glow.removeAction(forKey: "flash")
        core.removeAction(forKey: "flash")
        glow.run(
            .sequence([
                .fadeAlpha(to: 0.65, duration: 0.04),
                .fadeAlpha(to: baseGlowAlpha, duration: 0.22)
            ]),
            withKey: "flash"
        )
        core.run(
            .sequence([
                .fadeAlpha(to: 1.0, duration: 0.04),
                .fadeAlpha(to: 0.9, duration: 0.22)
            ]),
            withKey: "flash"
        )
    }
}
