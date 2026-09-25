import SpriteKit
import UIKit

/// Programmatic textures and particle setups, so the build carries no art asset.
enum Effects {

    /// Built once: every burst and pulse shares this texture.
    private static let spark: SKTexture = makeSparkTexture()

    /// Birth rate while a burst is firing. Kept here because the emitter is parked at 0
    /// between hits -- an emitter added to a scene with a non-zero rate fires once on the
    /// spot, which would flash all four targets as the playfield is built.
    private static let burstBirthRate: CGFloat = 900

    private static func makeSparkTexture(diameter: CGFloat = 20) -> SKTexture {
        let size = CGSize(width: diameter, height: diameter)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let centre = CGPoint(x: diameter / 2, y: diameter / 2)
            let colors = [
                UIColor.white.cgColor,
                UIColor.white.withAlphaComponent(0.0).cgColor
            ]
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 1]
            ) {
                context.cgContext.drawRadialGradient(
                    gradient,
                    startCenter: centre,
                    startRadius: 0,
                    endCenter: centre,
                    endRadius: diameter / 2,
                    options: []
                )
            } else {
                // A hard dot is worse-looking but never absent.
                UIColor.white.setFill()
                context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
            }
        }
        return SKTexture(image: image)
    }

    /// A one-shot radial burst in `color`. Replay with `resetSimulation()`.
    static func makeBurst(color: UIColor, motion: MotionSettings) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = spark
        emitter.particleBlendMode = .add
        emitter.particleColor = color
        emitter.particleColorSequence = nil
        emitter.particleColorBlendFactor = 1.0

        emitter.numParticlesToEmit = Int(40 * motion.particleCountScale)
        emitter.particleLifetime = 0.35
        emitter.particleLifetimeRange = 0.12

        emitter.emissionAngle = 0
        emitter.emissionAngleRange = .pi * 2
        emitter.particleSpeed = 150
        emitter.particleSpeedRange = 90

        emitter.particleAlpha = 0.9
        emitter.particleAlphaSpeed = -2.6
        emitter.particleScale = 0.28
        emitter.particleScaleRange = 0.14
        emitter.particleScaleSpeed = -0.5

        // Idle until a hit asks for it.
        emitter.particleBirthRate = 0
        return emitter
    }

    /// Replays a burst. A fixed `numParticlesToEmit` means it stops on its own.
    static func fire(_ emitter: SKEmitterNode) {
        emitter.particleBirthRate = burstBirthRate
        emitter.resetSimulation()
    }

    /// The white pulse that rides in from the screen edge and lands on the prism on the beat.
    static func makePulse(travel: CGFloat, duration: TimeInterval, angle: CGFloat) -> SKNode {
        let node = SKSpriteNode(texture: spark)
        node.size = CGSize(width: 26, height: 26)
        node.color = Theme.pulse
        node.colorBlendFactor = 1
        node.blendMode = .add
        node.alpha = 0
        node.zRotation = angle
        node.position = CGPoint(x: cos(angle) * travel, y: sin(angle) * travel)

        let target = CGPoint.zero
        node.run(.sequence([
            .group([
                .move(to: target, duration: duration),
                .sequence([
                    .fadeAlpha(to: 0.85, duration: duration * 0.35),
                    .fadeAlpha(to: 0.0, duration: duration * 0.65)
                ])
            ]),
            .removeFromParent()
        ]))
        return node
    }

    /// Subtle darkening toward the edges, so the centre reads as the brightest thing on screen.
    static func makeVignette(size: CGSize) -> SKNode {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            let colors = [
                UIColor.clear.cgColor,
                UIColor.black.withAlphaComponent(0.55).cgColor
            ]
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0.35, 1]
            ) else { return }
            context.cgContext.drawRadialGradient(
                gradient,
                startCenter: centre,
                startRadius: 0,
                endCenter: centre,
                endRadius: max(size.width, size.height) * 0.72,
                options: []
            )
        }
        let node = SKSpriteNode(texture: SKTexture(image: image))
        node.size = size
        node.zPosition = -1
        return node
    }
}
