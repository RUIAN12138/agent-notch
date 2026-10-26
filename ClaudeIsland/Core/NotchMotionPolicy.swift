// Modified by lihao505 for Agent Notch, 2026.
import SwiftUI

/// Compact motion contract for the high-frequency open/close interaction.
/// The spring stays interruptible; reduced motion removes spring overshoot and
/// uses short ease-out transitions.
struct NotchTransitionMotionProfile: Equatable, Sendable {
    let response: Double
    let dampingFraction: Double
    let reducedMotionDuration: Double

    func response(atSpeedMultiplier speedMultiplier: Double) -> Double {
        response / NotchMotionPolicy.sanitizedSpeedMultiplier(speedMultiplier)
    }

    func animation(
        reduceMotion: Bool,
        enabled: Bool = true,
        speedMultiplier: Double = NotchMotionPolicy.defaultSpeedMultiplier
    ) -> Animation {
        guard enabled else {
            return .linear(duration: 0)
        }

        if reduceMotion {
            // Keep the system's reduced-motion transition independent from
            // the user's spring-speed preference.
            return .easeOut(duration: reducedMotionDuration)
        }
        return .interactiveSpring(
            response: response(atSpeedMultiplier: speedMultiplier),
            dampingFraction: dampingFraction,
            blendDuration: 0
        )
    }
}

enum NotchMotionPolicy {
    static let speedMultiplierRange = 0.5...2.0
    static let defaultSpeedMultiplier = 1.0

    static func shouldTriggerAttentionBounce(
        reduceMotion: Bool,
        animationsEnabled: Bool
    ) -> Bool {
        animationsEnabled && !reduceMotion
    }

    static func sanitizedSpeedMultiplier(_ speedMultiplier: Double) -> Double {
        guard speedMultiplier.isFinite else {
            return defaultSpeedMultiplier
        }
        return min(
            max(speedMultiplier, speedMultiplierRange.lowerBound),
            speedMultiplierRange.upperBound
        )
    }

    static let opening = NotchTransitionMotionProfile(
        response: 0.38,
        dampingFraction: 0.8,
        reducedMotionDuration: 0.12
    )

    /// Closing responds more quickly than opening while retaining the same
    /// interruptible spring behavior, so a quick pointer return feels crisp.
    static let closing = NotchTransitionMotionProfile(
        response: 0.30,
        dampingFraction: 0.9,
        reducedMotionDuration: 0.10
    )

    /// Completion attention stays noticeable without the strong overshoot of
    /// the old hard-coded spring, and follows the same speed/accessibility
    /// preferences as the notch shell.
    static let attentionBounce = NotchTransitionMotionProfile(
        response: 0.32,
        dampingFraction: 0.82,
        reducedMotionDuration: 0.10
    )
}
