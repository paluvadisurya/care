import SwiftUI

/// Care's motion language. Four springs and one reduced fallback, used by name everywhere.
///
/// The rule behind them: motion explains cause and effect. A card grows into the screen it opens because it
/// *became* that screen. A number rolls because it changed. Nothing moves to decorate.
public enum CareMotion {
    /// Cards, sheets, chip selection, tab changes.
    public static let standard = Animation.spring(duration: 0.35, bounce: 0.15)
    /// Toggles, counters, small state changes.
    public static let snappy = Animation.spring(duration: 0.25, bounce: 0)
    /// Celebrations only: a milestone reached, a first insight, a streak of care.
    public static let expressive = Animation.spring(duration: 0.5, bounce: 0.3)
    /// Long, soft moves: an aura crossfade, a background settling.
    public static let gentle = Animation.easeInOut(duration: 0.35)
    /// What every spring becomes under Reduce Motion.
    public static let reduced = Animation.easeInOut(duration: 0.2)

    public static func standard(reduced flag: Bool) -> Animation { flag ? reduced : standard }
    public static func snappy(reduced flag: Bool) -> Animation { flag ? reduced : snappy }
    public static func expressive(reduced flag: Bool) -> Animation { flag ? reduced : expressive }
    public static func gentle(reduced flag: Bool) -> Animation { flag ? reduced : gentle }

    /// Delay between entering blocks in a stagger.
    public static let stagger: Double = 0.06
    /// The aura crossfade when the selected person changes.
    public static let auraCrossfade: Double = 0.35
}

/// Every tappable surface: a small scale, a light impact, interruptible.
public struct PressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    public var scale: CGFloat

    public init(scale: CGFloat = 0.96) { self.scale = scale }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(isEnabled ? (configuration.isPressed ? 0.92 : 1) : 0.45)
            .animation(CareMotion.snappy(reduced: reduceMotion), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, pressed in pressed }
    }
}

public extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
    static func pressable(scale: CGFloat) -> PressableButtonStyle { PressableButtonStyle(scale: scale) }
}

/// Entrance for a block in a staggered list: opacity, a touch of scale, a touch of blur, offset from below.
public struct StaggeredEntrance: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    public var index: Int

    public init(index: Int) { self.index = index }

    public func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : 0.97, anchor: .top)
            .blur(radius: shown ? 0 : 3)
            .offset(y: shown ? 0 : 10)
            .task {
                guard !shown else { return }
                if reduceMotion { shown = true; return }
                try? await Task.sleep(for: .milliseconds(Int(Double(index) * CareMotion.stagger * 1000)))
                withAnimation(CareMotion.standard) { shown = true }
            }
    }
}

/// Which way a change is travelling, so content enters from the side it came from.
public enum CareDirection: Sendable, Hashable {
    case forward, backward, none

    var insertionEdge: Edge { self == .backward ? .leading : .trailing }
    var removalEdge: Edge { self == .backward ? .trailing : .leading }
}

public extension View {
    func staggeredEntrance(index: Int) -> some View { modifier(StaggeredEntrance(index: index)) }

    /// Cards scale and fade slightly as they reach the edges of a scroll view.
    func careScrollTransition() -> some View {
        scrollTransition(.interactive) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1 : 0.95)
                .opacity(phase.isIdentity ? 1 : 0.55)
                .blur(radius: phase.isIdentity ? 0 : 1.5)
        }
    }

    /// A directional slide with a crossfade, used when a screen's content is replaced in place.
    func careDirectionalTransition(_ direction: CareDirection, distance: CGFloat = 18) -> some View {
        transition(
            .asymmetric(
                insertion: .offset(x: direction == .none ? 0 : (direction == .backward ? -distance : distance))
                    .combined(with: .opacity),
                removal: .opacity
            )
        )
    }

    /// Semantic haptics. Completing something feels different from selecting something.
    func careFeedback<T: Equatable>(_ feedback: SensoryFeedback, trigger: T) -> some View {
        sensoryFeedback(feedback, trigger: trigger)
    }
}

// MARK: - Shared zoom namespace

/// The namespace zoom transitions are matched in. Set once by the root view and read by any card that can
/// grow into a detail screen, so a screen never has to thread a `Namespace.ID` through its initialisers.
public struct CareZoomNamespaceKey: EnvironmentKey {
    public static let defaultValue: Namespace.ID? = nil
}

public extension EnvironmentValues {
    var careZoomNamespace: Namespace.ID? {
        get { self[CareZoomNamespaceKey.self] }
        set { self[CareZoomNamespaceKey.self] = newValue }
    }
}

/// Marks a card as the thing a detail screen grows out of. No-ops when no namespace is in the environment.
public struct ZoomSourceModifier<ID: Hashable>: ViewModifier {
    @Environment(\.careZoomNamespace) private var namespace
    public var id: ID

    public func body(content: Content) -> some View {
        if let namespace {
            content.matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}

/// The destination half. No-ops when no namespace is in the environment.
public struct ZoomDestinationModifier<ID: Hashable>: ViewModifier {
    @Environment(\.careZoomNamespace) private var namespace
    public var id: ID

    public func body(content: Content) -> some View {
        if let namespace {
            content.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            content
        }
    }
}

public extension View {
    /// The card a detail screen grows from.
    func careZoomSource<ID: Hashable>(_ id: ID) -> some View { modifier(ZoomSourceModifier(id: id)) }
    /// The screen that grew from it.
    func careZoomDestination<ID: Hashable>(_ id: ID) -> some View { modifier(ZoomDestinationModifier(id: id)) }
    /// The screen gutter. The only horizontal padding a screen should apply.
    func careGutter() -> some View { padding(.horizontal, CareSpace.gutter) }
}
