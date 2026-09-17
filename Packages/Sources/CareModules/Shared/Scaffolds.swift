import SwiftUI
import CareCore
import CareDesign
import CareData

/// The frame every module detail screen uses: the person's mesh, a header that states where you are and how
/// things stand, the content, and an optional floating action that never sits on top of the last row.
public struct ModuleScreen<Content: View>: View {
    @Environment(CareStore.self) private var store
    public var person: PersonRecord
    public var module: ModuleID
    public var actionTitle: String?
    public var action: (() -> Void)?
    public var content: Content

    public init(person: PersonRecord, module: ModuleID, actionTitle: String? = nil,
                action: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.person = person
        self.module = module
        self.actionTitle = actionTitle
        self.action = action
        self.content = content()
    }

    private var meta: ModuleMeta { ModuleCatalog.meta(module) }

    public var body: some View {
        ZStack(alignment: .bottom) {
            MeshBackground(aura: person.aura, intensity: 0.7)
            ScrollView {
                VStack(alignment: .leading, spacing: CareLayout.sectionGap) {
                    ModuleScreenHeader(person: person, module: module,
                                       state: store.todayState(for: person, module: module))
                    content
                }
                .careGutter()
                .padding(.top, CareSpace.xs)
                .padding(.bottom, action == nil ? CareLayout.sectionGap : CareLayout.actionBottomInset)
            }
            .scrollIndicators(.hidden)

            if let actionTitle, let action {
                PillButton(actionTitle, symbol: "plus", style: .ink, action: action)
                    .careGutter()
                    // A module screen is pushed inside a tab, so the action clears the tab bar instead
                    // of sitting behind it.
                    .padding(.bottom, CareLayout.actionBarBottom)
                    .background {
                        // A soft scrim so content scrolling under the action stays legible.
                        LinearGradient(colors: [CareColor.background.opacity(0), CareColor.background.opacity(0.92)],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: 160)
                            .allowsHitTesting(false)
                            .ignoresSafeArea()
                    }
            }
        }
        .navigationTitle(meta.name)
        .navigationBarTitleDisplayMode(.inline)
        .careMinimizingNavigationBar()
    }
}

/// Where you are, whose it is, and how the module stands right now.
struct ModuleScreenHeader: View {
    var person: PersonRecord
    var module: ModuleID
    var state: ModuleTodayState

    private var meta: ModuleMeta { ModuleCatalog.meta(module) }

    var body: some View {
        // Centre alignment, so the ring sits beside the headline it belongs to rather than floating up
        // beside the eyebrow. It stays put as the detail line grows to two or three lines.
        HStack(alignment: .center, spacing: CareSpace.sm) {
            VStack(alignment: .leading, spacing: CareSpace.xxs) {
                HStack(spacing: 6) {
                    PersonOrb(person: person, size: .inline)
                    Text("\(person.shortName) · \(meta.name)")
                        .careType(.labelEmphasis)
                        .foregroundStyle(CareColor.textSecondary)
                }
                Text(state.headline)
                    .careType(.screenTitle)
                    .foregroundStyle(state.tone == .attention ? CareColor.attention : CareColor.textPrimary)
                    .rollingNumber()
                Text(state.detail)
                    .careType(.callout)
                    .foregroundStyle(CareColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if let progress = state.progress {
                // The headline already reads "2 of 3", so the ring is the shape of that fraction, not a
                // second copy of it.
                Ring(bare: progress, size: .hero,
                     gradient: [ModuleAccent.color(for: module), person.aura.endColor])
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A titled group inside a module screen.
public struct CardSection<Content: View>: View {
    public var title: String
    public var trailing: String?
    public var content: Content

    public init(_ title: String, trailing: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.trailing = trailing
        self.content = content()
    }

    public var body: some View {
        CareSection(title, trailing: trailing) {
            VStack(alignment: .leading, spacing: CareLayout.stackGap - 4) {
                content
            }
        }
    }
}

/// A row inside a list: a tinted glyph, a title, a subtitle, and whatever the row needs on the right.
public struct CardRow<Trailing: View>: View {
    public var symbol: String?
    public var title: String
    public var subtitle: String?
    public var tint: Color
    public var isDone: Bool
    public var trailing: Trailing

    public init(symbol: String? = nil, title: String, subtitle: String? = nil, tint: Color = CareColor.textSecondary,
                isDone: Bool = false, @ViewBuilder trailing: () -> Trailing) {
        self.symbol = symbol
        self.title = title
        self.subtitle = subtitle
        self.tint = tint
        self.isDone = isDone
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: CareSpace.sm) {
            if let symbol {
                GlyphTile(symbol: symbol, tint: tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .careType(.bodyEmphasis)
                    .foregroundStyle(isDone ? CareColor.textMuted : CareColor.textPrimary)
                    .strikethrough(isDone, color: CareColor.textMuted)
                    .lineLimit(2)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .careType(.caption)
                        .foregroundStyle(CareColor.textMuted)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: CareSpace.xs)
            trailing
        }
        .frame(minHeight: CareLayout.touchTarget)
        .careSurface(.row)
        .accessibilityElement(children: .combine)
    }
}

public extension CardRow where Trailing == EmptyView {
    init(symbol: String? = nil, title: String, subtitle: String? = nil, tint: Color = CareColor.textSecondary, isDone: Bool = false) {
        self.init(symbol: symbol, title: title, subtitle: subtitle, tint: tint, isDone: isDone) { EmptyView() }
    }
}

/// A round check control with a success haptic and a symbol bounce on completion.
public struct CheckToggle: View {
    @Binding public var isOn: Bool
    public var tint: Color
    public var label: String

    public init(isOn: Binding<Bool>, tint: Color = CareColor.positive, label: String = "Done") {
        _isOn = isOn
        self.tint = tint
        self.label = label
    }

    public var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                .careSymbol(.xlarge, weight: .regular)
                .foregroundStyle(isOn ? tint : CareColor.textMuted)
                .symbolEffect(.bounce, value: isOn)
                .frame(width: CareLayout.touchTarget, height: CareLayout.touchTarget)
                .contentShape(Circle())
        }
        .buttonStyle(.pressable(scale: 0.88))
        .sensoryFeedback(.success, trigger: isOn) { _, new in new }
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// The frame every sheet uses: a title block, scrolling content, and one primary action pinned above the
/// home indicator with a scrim so nothing scrolls awkwardly underneath it.
public struct SheetScaffold<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    public var title: String
    public var subtitle: String?
    public var aura: Aura?
    public var primaryTitle: String
    public var primaryEnabled: Bool
    public var onPrimary: () -> Void
    public var content: Content

    public init(title: String, subtitle: String? = nil, aura: Aura? = nil, primaryTitle: String = "Save",
                primaryEnabled: Bool = true, onPrimary: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.aura = aura
        self.primaryTitle = primaryTitle
        self.primaryEnabled = primaryEnabled
        self.onPrimary = onPrimary
        self.content = content()
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            if let aura {
                MeshBackground(aura: aura, intensity: 0.85)
            } else {
                CareColor.background.ignoresSafeArea()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: CareLayout.sectionGap) {
                    HStack(alignment: .top, spacing: CareSpace.sm) {
                        ScreenTitle(eyebrow: subtitle, lead: title, role: .sheetTitle)
                        Spacer(minLength: 0)
                        IconButton("xmark", label: "Close") { dismiss() }
                    }
                    content
                }
                .careGutter()
                .padding(.top, CareSpace.md)
                .padding(.bottom, CareLayout.actionBottomInset)
            }
            .scrollIndicators(.hidden)

            PillButton(primaryTitle, style: .ink) {
                onPrimary()
                dismiss()
            }
            .disabled(!primaryEnabled)
            .careGutter()
            .padding(.bottom, CareSpace.sm)
            .background {
                LinearGradient(colors: [CareColor.background.opacity(0), CareColor.background.opacity(0.94)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 120)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(CareRadius.hero)
    }
}

/// A labelled text field. Reserves a full touch target and shows focus with the ink border.
public struct CareField: View {
    @FocusState private var isFocused: Bool
    public var label: String
    public var placeholder: String
    @Binding public var text: String
    public var axis: Axis

    public init(_ label: String, placeholder: String = "", text: Binding<String>, axis: Axis = .horizontal) {
        self.label = label
        self.placeholder = placeholder
        _text = text
        self.axis = axis
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .careType(.label)
                .foregroundStyle(CareColor.textSecondary)
            TextField(placeholder, text: $text, axis: axis)
                .careType(.body)
                .foregroundStyle(CareColor.textPrimary)
                .focused($isFocused)
                .padding(.horizontal, CareSpace.sm)
                .frame(minHeight: CareLayout.touchTarget + 4)
                .careSurface(.field, padding: 0)
                .overlay {
                    RoundedRectangle(cornerRadius: CareRadius.inner)
                        .strokeBorder(isFocused ? CareColor.ink : .clear, lineWidth: 1.5)
                }
                .animation(CareMotion.snappy, value: isFocused)
        }
    }
}

/// A date or time row in the same visual language as `CareField`.
public struct CareDateRow: View {
    public var label: String
    @Binding public var date: Date
    public var components: DatePickerComponents

    public init(_ label: String, date: Binding<Date>, components: DatePickerComponents = [.date, .hourAndMinute]) {
        self.label = label
        _date = date
        self.components = components
    }

    public var body: some View {
        HStack {
            Text(label)
                .careType(.label)
                .foregroundStyle(CareColor.textSecondary)
            Spacer(minLength: CareSpace.xs)
            DatePicker(label, selection: $date, displayedComponents: components)
                .labelsHidden()
                .tint(CareColor.ink)
        }
        .padding(.horizontal, CareSpace.sm)
        .frame(minHeight: CareLayout.touchTarget + 4)
        .careSurface(.field, padding: 0)
    }
}

/// A switch row with an optional explanation underneath its label.
public struct CareToggleRow: View {
    public var label: String
    public var detail: String?
    @Binding public var isOn: Bool

    public init(_ label: String, detail: String? = nil, isOn: Binding<Bool>) {
        self.label = label
        self.detail = detail
        _isOn = isOn
    }

    public var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .careType(.bodyEmphasis)
                    .foregroundStyle(CareColor.textPrimary)
                if let detail {
                    Text(detail)
                        .careType(.caption)
                        .foregroundStyle(CareColor.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(CareColor.ink)
        .padding(.horizontal, CareSpace.sm)
        .frame(minHeight: 54)
        .careSurface(.field, padding: 0)
        .sensoryFeedback(.selection, trigger: isOn)
    }
}

/// A stepper row: a label, the current value, and the control.
public struct CareStepperRow: View {
    public var label: String
    public var valueText: String
    @Binding public var value: Int
    public var range: ClosedRange<Int>
    public var step: Int

    public init(_ label: String, valueText: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int = 1) {
        self.label = label
        self.valueText = valueText
        _value = value
        self.range = range
        self.step = step
    }

    public var body: some View {
        HStack {
            Text(label)
                .careType(.label)
                .foregroundStyle(CareColor.textSecondary)
            Spacer(minLength: CareSpace.xs)
            Text(valueText)
                .careType(.bodyEmphasis)
                .foregroundStyle(CareColor.textPrimary)
                .rollingNumber()
            Stepper(label, value: $value, in: range, step: step)
                .labelsHidden()
                .tint(CareColor.ink)
        }
        .padding(.horizontal, CareSpace.sm)
        .frame(minHeight: CareLayout.touchTarget + 4)
        .careSurface(.field, padding: 0)
        .sensoryFeedback(.increase, trigger: value)
    }
}
