import SwiftUI
import CareCore
import CareDesign
import CareData

/// Common frame for a module's detail screen: mesh background, header with today's state, content, floating action.
public struct ModuleScreen<Content: View>: View {
    @Environment(CareStore.self) private var store
    public var person: PersonRecord
    public var module: ModuleID
    public var actionTitle: String?
    public var action: (() -> Void)?
    public var content: Content

    public init(person: PersonRecord, module: ModuleID, actionTitle: String? = nil, action: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.person = person
        self.module = module
        self.actionTitle = actionTitle
        self.action = action
        self.content = content()
    }

    public var body: some View {
        let meta = ModuleCatalog.meta(module)
        let state = store.todayState(for: person, module: module)
        ZStack(alignment: .bottom) {
            MeshBackground(aura: person.aura, intensity: 0.7)
            ScrollView {
                VStack(alignment: .leading, spacing: CareSpace.md) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                PersonOrb(initials: person.initials, aura: person.aura, size: 22)
                                Text("\(person.shortName) · \(meta.name)")
                                    .font(CareFont.labelSemi)
                                    .foregroundStyle(CareColor.textSecondary)
                            }
                            Text(state.headline)
                                .font(CareFont.display(34))
                                .displayTracking(34)
                                .foregroundStyle(state.tone == .attention ? CareColor.attention : CareColor.textPrimary)
                                .contentTransition(.numericText())
                            Text(state.detail)
                                .font(CareFont.callout)
                                .foregroundStyle(CareColor.textSecondary)
                        }
                        Spacer()
                        if let p = state.progress {
                            Ring(progress: p, size: 64, lineWidth: 8, gradient: [ModuleAccent.color(for: module), person.aura.endColor])
                        }
                    }
                    .padding(.horizontal, CareSpace.gutter)
                    .padding(.top, CareSpace.xs)
                    content
                        .padding(.horizontal, CareSpace.gutter)
                }
                .padding(.bottom, actionTitle == nil ? CareSpace.xl : 96)
            }
            .scrollIndicators(.hidden)
            .careSwipeActionsContainer()
            if let actionTitle, let action {
                PillButton(actionTitle, symbol: "plus", style: .ink, action: action)
                    .padding(.horizontal, CareSpace.gutter)
                    .padding(.bottom, CareSpace.md)
            }
        }
        .navigationTitle(meta.name)
        .navigationBarTitleDisplayMode(.inline)
        .careMinimizingNavigationBar()
    }
}

/// A card list section with a title. Rows are whatever you pass.
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
        VStack(alignment: .leading, spacing: CareSpace.xs) {
            SectionLabel(title, trailing: trailing)
            content
        }
    }
}

/// A row inside a card list: leading symbol, title, subtitle, trailing view.
public struct CardRow<Trailing: View>: View {
    public var symbol: String?
    public var title: String
    public var subtitle: String?
    public var tint: Color
    public var isDone: Bool
    public var trailing: Trailing

    public init(symbol: String? = nil, title: String, subtitle: String? = nil, tint: Color = CareColor.textSecondary, isDone: Bool = false, @ViewBuilder trailing: () -> Trailing) {
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
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: CareRadius.small))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(CareFont.bodyMedium)
                    .foregroundStyle(isDone ? CareColor.textMuted : CareColor.textPrimary)
                    .strikethrough(isDone, color: CareColor.textMuted)
                    .lineLimit(2)
                if let subtitle {
                    Text(subtitle)
                        .font(CareFont.caption)
                        .foregroundStyle(CareColor.textMuted)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            trailing
        }
        .careCard(radius: CareRadius.tile, padding: CareSpace.sm)
    }
}

public extension CardRow where Trailing == EmptyView {
    init(symbol: String? = nil, title: String, subtitle: String? = nil, tint: Color = CareColor.textSecondary, isDone: Bool = false) {
        self.init(symbol: symbol, title: title, subtitle: subtitle, tint: tint, isDone: isDone) { EmptyView() }
    }
}

/// A small round check control used by lists.
public struct CheckToggle: View {
    @Binding public var isOn: Bool
    public var tint: Color

    public init(isOn: Binding<Bool>, tint: Color = CareColor.positive) {
        _isOn = isOn
        self.tint = tint
    }

    public var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(isOn ? tint : CareColor.textMuted)
                .symbolEffect(.bounce, value: isOn)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.pressable(scale: 0.9))
        .sensoryFeedback(.success, trigger: isOn) { _, new in new }
        .accessibilityLabel(isOn ? "Done" : "Not done")
    }
}

/// Standard sheet frame: title, content, a primary pill. Sheets own their dismiss.
public struct SheetScaffold<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    public var title: String
    public var subtitle: String?
    public var aura: Aura?
    public var primaryTitle: String
    public var primaryEnabled: Bool
    public var onPrimary: () -> Void
    public var content: Content

    public init(title: String, subtitle: String? = nil, aura: Aura? = nil, primaryTitle: String = "Save", primaryEnabled: Bool = true, onPrimary: @escaping () -> Void, @ViewBuilder content: () -> Content) {
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
            if let aura { MeshBackground(aura: aura, intensity: 0.8) } else { CareColor.background.ignoresSafeArea() }
            ScrollView {
                VStack(alignment: .leading, spacing: CareSpace.md) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            if let subtitle {
                                Text(subtitle).font(CareFont.labelSemi).foregroundStyle(CareColor.textSecondary)
                            }
                            Text(title).font(CareFont.display(28)).displayTracking(28).foregroundStyle(CareColor.textPrimary)
                        }
                        Spacer()
                        IconButton("xmark", label: "Close") { dismiss() }
                    }
                    content
                }
                .padding(CareSpace.gutter)
                .padding(.bottom, 80)
            }
            .scrollIndicators(.hidden)
            PillButton(primaryTitle, style: .ink) {
                onPrimary()
                dismiss()
            }
            .disabled(!primaryEnabled)
            .opacity(primaryEnabled ? 1 : 0.5)
            .padding(.horizontal, CareSpace.gutter)
            .padding(.bottom, CareSpace.sm)
            .sensoryFeedback(.success, trigger: primaryEnabled)
        }
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(CareRadius.hero)
    }
}

/// A labelled text field in Care's style.
public struct CareField: View {
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
            Text(label).font(CareFont.label).foregroundStyle(CareColor.textSecondary)
            TextField(placeholder, text: $text, axis: axis)
                .font(CareFont.body)
                .foregroundStyle(CareColor.textPrimary)
                .padding(.horizontal, CareSpace.sm)
                .frame(minHeight: 46)
                .background(CareColor.surfaceStrong, in: RoundedRectangle(cornerRadius: CareRadius.inner))
                .overlay { RoundedRectangle(cornerRadius: CareRadius.inner).strokeBorder(CareColor.separator) }
        }
    }
}

/// Date and time picker rows in the same style.
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
            Text(label).font(CareFont.label).foregroundStyle(CareColor.textSecondary)
            Spacer()
            DatePicker(label, selection: $date, displayedComponents: components)
                .labelsHidden()
                .tint(CareColor.ink)
        }
        .padding(.horizontal, CareSpace.sm)
        .frame(minHeight: 46)
        .background(CareColor.surfaceStrong, in: RoundedRectangle(cornerRadius: CareRadius.inner))
        .overlay { RoundedRectangle(cornerRadius: CareRadius.inner).strokeBorder(CareColor.separator) }
    }
}

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
                Text(label).font(CareFont.bodyMedium).foregroundStyle(CareColor.textPrimary)
                if let detail { Text(detail).font(CareFont.caption).foregroundStyle(CareColor.textMuted) }
            }
        }
        .tint(CareColor.ink)
        .padding(.horizontal, CareSpace.sm)
        .frame(minHeight: 52)
        .background(CareColor.surfaceStrong, in: RoundedRectangle(cornerRadius: CareRadius.inner))
        .overlay { RoundedRectangle(cornerRadius: CareRadius.inner).strokeBorder(CareColor.separator) }
    }
}
