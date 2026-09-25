import SpriteKit

/// Renders the playfield and reads the player's finger. Nothing more.
///
/// Per the architecture rule, the scene never judges and never scores: it reports the
/// prism angle it is actually displaying and lets `GameSession` decide what that was worth.
/// Reporting the *displayed* angle rather than the finger's angle matters -- the player is
/// aiming with their eyes, so the thing on screen has to be the thing being judged.
final class GameScene: SKScene {

    /// How fast the prism catches up to the finger. Higher is snappier and twitchier.
    private static let lerpRate: Double = 25
    /// atan2 is meaningless near the centre, so a small dead zone protects the rotation.
    private static let centreDeadZone: CGFloat = 40
    /// A resumed or hitching frame must not teleport the prism.
    private static let maxFrameDelta: Double = 1.0 / 20.0

    private let layout: Layout
    private let beatDuration: TimeInterval
    private let motion: MotionSettings

    private let rotor = SKNode()
    private let pulseLayer = SKNode()
    private var prism: PrismNode?
    private var beams: [BeamColor: BeamNode] = [:]
    private var targets: [TargetNode] = []
    private var vignette: SKNode?

    /// Unbounded, accumulated from the finger. Drives haptic detents.
    private var commandedAngle: Double = 0
    /// What is on screen this frame. Drives judgment.
    private var displayedAngle: Double = 0

    private var trackedTouch: UITouch?
    private var lastTouchAngle: Double?
    private var lastUpdateTime: TimeInterval?

    /// (displayed prism angle, delta time) once per rendered frame.
    var onFrame: ((Double, Double) -> Void)?
    /// Unbounded commanded angle, for 15 degree haptic detents.
    var onRotate: ((Double) -> Void)?
    /// A drag started; a good moment to prime the feedback generators.
    var onGestureBegan: (() -> Void)?

    init(size: CGSize, layout: Layout, beatDuration: TimeInterval, motion: MotionSettings) {
        self.layout = layout
        self.beatDuration = beatDuration
        self.motion = motion
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = Theme.backgroundUI
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("GameScene is created in code only")
    }

    // MARK: - Build

    override func didMove(to view: SKView) {
        guard prism == nil else { return }
        buildPlayfield()
        layoutPlayfield()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutPlayfield()
    }

    private var orbitRadius: CGFloat {
        min(size.width, size.height) * 0.33
    }

    private var prismRadius: CGFloat {
        min(size.width, size.height) * 0.075
    }

    private func buildPlayfield() {
        let prismNode = PrismNode(radius: prismRadius)
        prism = prismNode

        for beam in BeamColor.allCases {
            let node = BeamNode(beam: beam, length: orbitRadius)
            beams[beam] = node
            rotor.addChild(node)
        }
        rotor.addChild(prismNode)
        rotor.zPosition = 10

        for index in 0..<layout.targetCount {
            let node = TargetNode(
                targetIndex: index,
                beam: layout.targetColors[index],
                radius: min(size.width, size.height) * 0.055,
                motion: motion
            )
            targets.append(node)
            addChild(node)
        }

        pulseLayer.zPosition = 5
        addChild(pulseLayer)
        addChild(rotor)
    }

    /// Positions everything for the current size. Separate from `buildPlayfield` so a size
    /// change repositions without rebuilding nodes and losing in-flight animations.
    private func layoutPlayfield() {
        guard !targets.isEmpty else { return }

        vignette?.removeFromParent()
        let newVignette = Effects.makeVignette(size: size)
        addChild(newVignette)
        vignette = newVignette

        for node in beams.values {
            node.updateLength(orbitRadius)
        }

        for target in targets {
            let angle = layout.targetAngles[target.targetIndex]
            target.position = CGPoint(
                x: cos(angle) * orbitRadius,
                y: sin(angle) * orbitRadius
            )
        }
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard trackedTouch == nil, let touch = touches.first else { return }
        trackedTouch = touch
        lastTouchAngle = angle(of: touch)
        onGestureBegan?()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = trackedTouch, touches.contains(touch) else { return }

        let location = touch.location(in: self)
        // Inside the dead zone the reported angle is noise, so hold the last one and wait
        // for the finger to come back out rather than snapping the prism somewhere random.
        guard hypot(location.x, location.y) > Self.centreDeadZone else { return }

        let current = angle(of: touch)
        if let previous = lastTouchAngle {
            commandedAngle += AngleMath.shortestDelta(previous, current)
            onRotate?(commandedAngle)
        }
        lastTouchAngle = current
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTracking(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTracking(touches)
    }

    private func endTracking(_ touches: Set<UITouch>) {
        guard let touch = trackedTouch, touches.contains(touch) else { return }
        trackedTouch = nil
        lastTouchAngle = nil
    }

    private func angle(of touch: UITouch) -> Double {
        let location = touch.location(in: self)
        return atan2(Double(location.y), Double(location.x))
    }

    // MARK: - Frame

    override func update(_ currentTime: TimeInterval) {
        // Only a tick. Song time comes from the audio clock, never from here.
        let delta = min(currentTime - (lastUpdateTime ?? currentTime), Self.maxFrameDelta)
        lastUpdateTime = currentTime

        if delta > 0 {
            // Frame-rate independent easing: identical feel at 60 and 120 Hz.
            let factor = 1 - exp(-Self.lerpRate * delta)
            displayedAngle += AngleMath.shortestDelta(displayedAngle, commandedAngle) * factor
            rotor.zRotation = CGFloat(displayedAngle)
        }

        onFrame?(displayedAngle, delta)
    }

    // MARK: - Driven by GameSession events

    func telegraph(_ note: Note) {
        guard targets.indices.contains(note.targetIndex) else { return }
        targets[note.targetIndex].telegraph(duration: beatDuration)

        // White light rides in from the edge and lands on the prism exactly on the beat.
        let angle = CGFloat(layout.targetAngles[note.targetIndex])
        pulseLayer.addChild(
            Effects.makePulse(travel: edgeDistance(along: angle), duration: beatDuration, angle: angle)
        )
    }

    /// Distance from the centre to where `angle` leaves the screen.
    ///
    /// Using one radius for every direction spawns the diagonal pulses well outside a
    /// portrait screen, so they stay invisible for the first third of their travel and the
    /// telegraph reads late. The rectangle has to be intersected properly.
    private func edgeDistance(along angle: CGFloat) -> CGFloat {
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2
        let horizontal = abs(cos(angle))
        let vertical = abs(sin(angle))

        let toSide = horizontal > 0.0001 ? halfWidth / horizontal : .greatestFiniteMagnitude
        let toTop = vertical > 0.0001 ? halfHeight / vertical : .greatestFiniteMagnitude
        return min(toSide, toTop)
    }

    func resolve(_ judgment: Judgment, note: Note) {
        guard targets.indices.contains(note.targetIndex) else { return }
        targets[note.targetIndex].resolve(judgment, motion: motion)
        if judgment == .perfect {
            beams[note.color]?.flash()
        }
    }

    func markDownbeat() {
        prism?.pulse(allowed: motion.allowsBackgroundMotion)
    }
}
