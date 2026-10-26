//
//  PixelLoaderIcon.swift
//  ClaudeIsland
//
//  Compact pixel-art loader used on the right side of the notch.
//

import AppKit
import SwiftUI

@MainActor
struct PixelLoaderIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let size: CGFloat

    private static let framesPerSecond: TimeInterval = 8
    private static let frameDuration: TimeInterval = 1 / framesPerSecond
    private static var frameCache: [String: NSImage] = [:]

    init(size: CGFloat = 19) {
        self.size = size
    }

    var body: some View {
        Group {
            if PixelMotionPolicy.shouldAnimate(reduceMotion: reduceMotion) {
                TimelineView(.periodic(from: .now, by: Self.frameDuration)) { context in
                    let elapsed = context.date.timeIntervalSinceReferenceDate
                    let frameIndex =
                        Int(elapsed / Self.frameDuration) % Self.frameNames.count
                    loaderArtwork(named: Self.frameNames[frameIndex])
                }
            } else {
                loaderArtwork(named: Self.stillFrameName)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func loaderArtwork(named name: String) -> some View {
        Group {
            if let frameImage = Self.frameImage(named: name) {
                Image(nsImage: frameImage)
                    .resizable()
                    .interpolation(.none)
                    .antialiased(false)
                    .aspectRatio(contentMode: .fit)
                    .saturation(1.03)
                    .brightness(0.04)
                    .shadow(
                        color: Self.glowColor,
                        radius: 1.3,
                        x: 0,
                        y: 0
                    )
            } else {
                Color.clear
            }
        }
    }

    private static let glowColor = Color(
        red: 0.36,
        green: 0.64,
        blue: 0.88
    ).opacity(0.26)
    private static let frameNames = (0...7).map {
        String(format: "%02d-blue-f%d", $0, $0 + 1)
    }
    private static var stillFrameName: String {
        let index = PixelMotionPolicy.representativeFrameIndex(
            count: frameNames.count
        ) ?? 0
        return frameNames[index]
    }

    private static func frameImage(named name: String) -> NSImage? {
        if let cached = frameCache[name] {
            return cached
        }

        guard let url = Bundle.main.url(
            forResource: name,
            withExtension: "png"
        ),
        let image = NSImage(contentsOf: url) else {
            return nil
        }

        frameCache[name] = image
        return image
    }
}

/// A calm amber orbit for "waiting for input". Rendering and movement speed
/// are independent: it refreshes at 30fps, but takes 3.2 seconds per orbit,
/// so it is smooth while remaining slower than the blue working comet.
@MainActor
struct WaitingPixelIndicatorIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let size: CGFloat

    init(size: CGFloat = 19) {
        self.size = size
    }

    var body: some View {
        Group {
            if PixelMotionPolicy.shouldAnimate(reduceMotion: reduceMotion) {
                TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { context in
                    orbitArtwork(progress: progress(at: context.date))
                }
            } else {
                orbitArtwork(progress: 0)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func progress(at date: Date) -> Double {
        date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: Self.orbitDuration)
            / Self.orbitDuration
    }

    private func orbitArtwork(progress: Double) -> some View {
        Canvas { canvas, _ in
            let scale = size / 20
            let block = 4 * scale
            let center = size / 2
            let radius = 7 * scale
            for trailIndex in 0..<3 {
                let angle =
                    progress * 2 * Double.pi
                    - Double.pi / 2
                    - Double(trailIndex) * 0.38
                let opacity = [1.0, 0.52, 0.22][trailIndex]
                canvas.fill(
                    Path(
                        CGRect(
                            x: center
                                + CGFloat(cos(angle)) * radius
                                - block / 2,
                            y: center
                                + CGFloat(sin(angle)) * radius
                                - block / 2,
                            width: block,
                            height: block
                        )
                    ),
                    with: .color(Self.color.opacity(opacity))
                )
            }
        }
        .shadow(
            color: Self.color.opacity(0.32),
            radius: 1.4
        )
    }

    private static let color = Color(
        red: 0.90,
        green: 0.58,
        blue: 0.32
    )
    private static let orbitDuration: TimeInterval = 3.2
}

#Preview {
    HStack {
        PixelLoaderIcon()
        WaitingPixelIndicatorIcon()
    }
    .padding()
    .background(.black)
}
