import SpriteKit

/// One of the four nodes on the outer orbit.
final class TargetNode: SKNode {

    let targetIndex: Int
    let beam: BeamColor

    private let radius: CGFloat
    private let ring: SKShapeNode
    private let dot: SKShapeNode
    /// The telegraph: shrinks from 2x to 1x across the beat before the hit.
    private let approach: SKShapeNode
    private let burst: SKEmitterNode

    init(targetIndex: Int, beam: BeamColor, radius: CGFloat, motion: MotionSettings) {
        self.targetIndex = targetIndex
        self.beam = beam
        self.radius = radius

        ring = SKShapeNode(circleOfRadius: radius)
        ring.strokeColor = beam.uiColor
        ring.lineWidth = 2
        ring.fillColor = .clear
        ring.blendMode = .add

        dot = SKShapeNode(circleOfRadius: radius * 0.34)
        dot.fillColor = beam.uiColor
        dot.strokeColor = .clear
        dot.blendMode = .add

        approach = SKShapeNode(circleOfRadius: radius)
        approach.strokeColor = beam.uiColor
        approach.lineWidth = 2.5
        approach.fillColor = .clear
        approach.blendMode = .add
        approach.alpha = 0
        approach.isHidden = true

        // Built once and replayed with resetSimulation(); allocating an emitter per hit
        // would stutter exactly on the beat the player is trying to feel.
        burst = Effects.makeBurst(color: beam.uiColor, motion: motion)

        super.init()
        alpha = Theme.idleTargetAlpha
        addChild(approach)
        addChild(ring)
        addChild(dot)
        addChild(burst)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("TargetNode is created in code only")
    }

    /// Starts the approach ring. `duration` is one beat.
    func telegraph(duration: TimeInterval) {
        approach.removeAllActions()
        approach.isHidden = false
        approach.setScale(2.0)
        approach.alpha = 1.0
        approach.run(
            .group([
                .scale(to: 1.0, duration: duration),
                .sequence([.wait(forDuration: duration), .hide()])
            ])
        )
        // Lift the target itself out of its idle dimness while it is being asked for.
        removeAction(forKey: "idle")
        run(.fadeAlpha(to: 1.0, duration: duration * 0.5), withKey: "idle")
    }

    func resolve(_ judgment: Judgment, motion: MotionSettings) {
        approach.removeAllActions()
        approach.isHidden = true

        switch judgment {
        case .perfect:
            Effects.fire(burst)
            if motion.allowsScalePulse {
                run(.sequence([
                    .scale(to: 1.25, duration: 0.06),
                    .scale(to: 1.0, duration: 0.06)
                ]))
            }
            flashRing(to: 1.0)
        case .good:
            Effects.fire(burst)
            flashRing(to: 0.8)
        case .miss:
            // No burst and no pulse. A miss should look like nothing happened.
            flashRing(to: Theme.idleTargetAlpha)
        }

        run(.fadeAlpha(to: Theme.idleTargetAlpha, duration: 0.25), withKey: "idle")
    }

    private func flashRing(to alpha: CGFloat) {
        ring.removeAction(forKey: "flash")
        ring.run(
            .sequence([
                .fadeAlpha(to: alpha, duration: 0.04),
                .fadeAlpha(to: 1.0, duration: 0.2)
            ]),
            withKey: "flash"
        )
    }
}
