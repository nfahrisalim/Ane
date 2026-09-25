import CoreHaptics
import UIKit
import os

/// Every haptic in the game, in one place.
///
/// A miss deliberately has no haptic: silence next to a dropped stem reads as loss far
/// more clearly than a buzz, and buzzing on failure punishes the hand that is already
/// behind.
@MainActor
final class Haptics {

    /// One tick per 15 degrees of rotation.
    private static let stepAngle = AngleMath.radians(degrees: 15)
    /// A fast spin would otherwise turn the ticks into a continuous buzz.
    private static let minimumTickInterval: TimeInterval = 0.012

    private let selection = UISelectionFeedbackGenerator()
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)

    private var engine: CHHapticEngine?
    private var lastStepIndex: Int?
    private var lastTickTime: TimeInterval = 0

    private let logger = Logger(subsystem: "com.dissent.academy.Ane", category: "haptics")

    private var supportsHaptics: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    init() {
        startEngine()
    }

    // MARK: - Rotation

    /// Call when a drag begins, so the first tick is not late.
    func prepareForRotation() {
        selection.prepare()
        rigidImpact.prepare()
        lastStepIndex = nil
    }

    /// Ticks on a fixed 15 degree grid.
    ///
    /// The obvious version -- comparing `abs(angle - lastAngle)` against the step -- breaks
    /// twice: it double-fires across the +/-pi seam, and because the remainder is discarded
    /// each time it slowly walks off the grid. Quantising the unbounded angle to a step
    /// index has neither problem, and ticks land on the same angles every run.
    func rotationTick(unboundedAngle: Double) {
        let stepIndex = Int((unboundedAngle / Self.stepAngle).rounded(.down))
        guard stepIndex != lastStepIndex else { return }

        let now = CACurrentMediaTime()
        // Still record the step, or a throttled tick would fire late on the next frame.
        lastStepIndex = stepIndex
        guard now - lastTickTime >= Self.minimumTickInterval else { return }
        lastTickTime = now

        selection.selectionChanged()
    }

    // MARK: - Judgment

    func play(_ judgment: Judgment) {
        switch judgment {
        case .perfect:
            rigidImpact.impactOccurred(intensity: 1.0)
            rigidImpact.prepare()
        case .good:
            softImpact.impactOccurred(intensity: 0.6)
            softImpact.prepare()
        case .miss:
            break
        }
    }

    // MARK: - Downbeat

    /// A very light transient on every 4th beat, scheduled off the audio clock.
    ///
    /// Barely perceptible on its own; what it does is put the beat in the hand as well as
    /// the ear, so the player can feel where they are even while looking at a target.
    func playDownbeat() {
        guard supportsHaptics, let engine else { return }
        do {
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                ],
                relativeTime: 0
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            logger.error("downbeat haptic failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Engine lifecycle

    private func startEngine() {
        guard supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            // The system stops the engine on backgrounding and after some interruptions;
            // without these the downbeat silently never returns for the rest of the session.
            engine.resetHandler = { [weak self] in
                self?.restart()
            }
            engine.stoppedHandler = { [weak self] _ in
                self?.restart()
            }
            try engine.start()
            self.engine = engine
        } catch {
            logger.error("haptic engine unavailable: \(error.localizedDescription, privacy: .public)")
        }
    }

    private nonisolated func restart() {
        Task { @MainActor [weak self] in
            guard let self, let engine = self.engine else { return }
            do {
                try engine.start()
            } catch {
                self.logger.error("haptic engine restart failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
