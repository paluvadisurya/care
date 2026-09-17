import SwiftUI

/// Exact motion values from the spec. Reduce Motion swaps springs for a 200 ms ease.
public enum CareMotion {
    public static let standard = Animation.spring(duration: 0.35, bounce: 0.15)
    public static let snappy = Animation.spring(duration: 0.25, bounce: 0)
    public static let expressive = Animation.spring(duration: 0.5, bounce: 0.3)
    public static let reduced = Animation.easeInOut(duration: 0.2)

    public static func standard(reduced: Bool) -> Animation { reduced ? Self.reduced : standard }
    public static func snappy(reduced: Bool) -> Animation { reduced ? Self.reduced : snappy }
    public static func expressive(reduced: Bool) -> Animation { reduced ? Self.reduced : expressive }

    /// Staggered entrance for insight blocks: 80 ms apart.
    public static let stagger: Double = 0.08
}

/// Every tappable surface: scale 0.96 while pressed with a light impact. Interruptible.
public struct PressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public var scale: CGFloat

    public init(scale: CGFloat = 0.96) { self.scale = scale }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(CareMotion.snappy(reduced: reduceMotion), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, pressed in pressed }
    }
}

public extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
    static func pressable(scale: CGFloat) -> PressableButtonStyle { PressableButtonStyle(scale: scale) }
}

/// Insight-block entrance: opacity 0 to 1, scale 0.96 to 1, blur 4 to 0, staggered by index.
public struct StaggeredEntrance: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    public var index: Int

    public init(index: Int) { self.index = index }

    public func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : 0.96)
            .blur(radius: shown ? 0 : 4)
            .task {
                if reduceMotion { shown = true; return }
                try? await Task.sleep(for: .milliseconds(Int(Double(index) * CareMotion.stagger * 1000)))
                withAnimation(CareMotion.standard) { shown = true }
            }
    }
}

public extension View {
    func staggeredEntrance(index: Int) -> some View { modifier(StaggeredEntrance(index: index)) }

    /// Scroll edge treatment from the spec: cards scale 0.94 to 1 and fade 0.6 to 1 near edges.
    func careScrollTransition() -> some View {
        scrollTransition(.interactive) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1 : 0.94)
                .opacity(phase.isIdentity ? 1 : 0.6)
        }
    }
}
