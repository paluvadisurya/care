import SwiftUI
import CareCore

/// The living background: a 3x3 mesh carrying the active person's aura, drifting slowly.
///
/// It is the only thing in the app that moves without being touched, so it moves very slowly and sits well
/// below the content in contrast. Still under Reduce Motion.
public struct MeshBackground: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public var aura: Aura
    public var intensity: Double

    public init(aura: Aura, intensity: Double = 1) {
        self.aura = aura
        self.intensity = intensity
    }

    public var body: some View {
        ZStack {
            CareColor.background
            Group {
                if reduceMotion {
                    mesh(time: 0)
                } else {
                    TimelineView(.animation(minimumInterval: 1 / 20)) { ctx in
                        mesh(time: ctx.date.timeIntervalSinceReferenceDate)
                    }
                }
            }
            .animation(.easeInOut(duration: CareMotion.auraCrossfade), value: aura)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func mesh(time: TimeInterval) -> some View {
        let t = Float(time * 0.1)
        func wobble(_ a: Float, _ b: Float) -> Float {
            0.5 + 0.16 * sin(t + a) * cos(t * 0.7 + b)
        }
        let points: [SIMD2<Float>] = [
            [0, 0], [0.5, 0], [1, 0],
            [0, wobble(0.3, 1.1)], [wobble(2.1, 0.4), wobble(1.3, 2.2)], [1, wobble(1.9, 0.9)],
            [0, 1], [0.5, 1], [1, 1],
        ]
        let bg = CareColor.background
        let colors: [Color] = [
            aura.startColor, bg, aura.endColor,
            bg, bg, bg,
            CareColor.amber, bg, aura.startColor.opacity(0.55),
        ]
        return MeshGradient(width: 3, height: 3, points: points, colors: colors, smoothsColors: true)
            .opacity((scheme == .dark ? 0.42 : 0.3) * intensity)
            .blur(radius: 34)
            .scaleEffect(1.2)
    }
}
