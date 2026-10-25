// Modified by lihao505 for Agent Notch, 2026.
import SwiftUI

/// Compact motion contract for the high-frequency open/close interaction.
/// The spring stays interruptible; reduced motion removes spring overshoot and
/// uses short ease-out transitions.
struct NotchTransitionMotionProfile: Equatable, Sendable {
    let response: Double
    let dampingFraction: Double
    let reducedMotionDuration: Double

    func animation(reduceMotion: Bool) -> Animation {
        if reduceMotion {
            return .easeOut(duration: reducedMotionDuration)
        }
        return .interactiveSpring(
            response: response,
            dampingFraction: dampingFraction,
            blendDuration: 0
        )
    }
}

enum NotchMotionPolicy {
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
}
