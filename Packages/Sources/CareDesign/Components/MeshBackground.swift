import SwiftUI
import CareCore

/// The living background. A 3x3 mesh with the active person's aura in two corners and amber at the bottom,
/// drifting slowly. Opacity 0.3 in light, 0.45 at night. Still under Reduce Motion.
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
            if reduceMotion {
                mesh(time: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1 / 24)) { ctx in
                    mesh(time: ctx.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func mesh(time: TimeInterval) -> some View {
        let t = Float(time * 0.12)
        let wobble = { (a: Float, b: Float) -> Float in 0.5 + 0.18 * sin(t + a) * cos(t * 0.7 + b) }
        let points: [SIMD2<Float>] = [
            [0, 0], [0.5, 0], [1, 0],
            [0, wobble(0.3, 1.1)], [wobble(2.1, 0.4), wobble(1.3, 2.2)], [1, wobble(1.9, 0.9)],
            [0, 1], [0.5, 1], [1, 1],
        ]
        let bg = CareColor.background
        let colors: [Color] = [
            aura.startColor, bg, aura.endColor,
            bg, bg, bg,
            CareColor.amber, bg, aura.startColor.opacity(0.6),
        ]
        return MeshGradient(width: 3, height: 3, points: points, colors: colors, smoothsColors: true)
            .opacity((scheme == .dark ? 0.45 : 0.3) * intensity)
            .blur(radius: 30)
            .scaleEffect(1.15)
    }
}

/// Aura crossfade for person switching: 350 ms.
public struct AuraTransitionModifier: ViewModifier {
    public var aura: Aura
    public func body(content: Content) -> some View {
        content
            .animation(.easeInOut(duration: 0.35), value: aura)
    }
}

public extension View {
    func auraTransition(_ aura: Aura) -> some View { modifier(AuraTransitionModifier(aura: aura)) }
}
