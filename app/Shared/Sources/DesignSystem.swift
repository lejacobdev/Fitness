import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Athlete OS's visual language: minimal, and big — made to be read and
/// tapped quickly between sets. The two main colours are black and white:
/// white canvas with black actions (light), black canvas with white actions
/// (dark). Red, coral and the others are accents — rings, highlights, the
/// logo, warnings. Neutral grey for secondary text; never blue.
/// Follows the system appearance; watchOS always gets the dark palette.
public enum AppTheme {
    public static let background = Color.dynamic(light: 0xFFFFFF, dark: 0x000000)
    public static let card = Color.dynamic(light: 0xF5F5F5, dark: 0x141414)
    /// Unselected chips/options, ring tracks, thumbnail wells.
    public static let fill = Color.dynamic(light: 0xEBEBEB, dark: 0x262626)
    /// Primary text.
    public static let ink = Color.dynamic(light: 0x000000, dark: 0xFFFFFF)
    /// Every action and selection: buttons, selected chips, the "+", the tab
    /// bar — black on white, white on black.
    public static let accent = Color.dynamic(light: 0x000000, dark: 0xFFFFFF)
    /// Text and glyphs drawn on `accent`.
    public static let onAccent = Color.dynamic(light: 0xFFFFFF, dark: 0x000000)
    /// Secondary text: a neutral grey, one shade deeper on white so small
    /// text stays readable.
    public static let secondaryText = Color.dynamic(light: 0x6E6E73, dark: 0x98989D)
    public static let hairline = Color.dynamic(light: 0xE5E5E5, dark: 0x262626)

    // Ring and highlight colours.
    public static let brand = Color(hex: "#E5383B")
    /// The second accent (rings, highlights): a lighter coral red.
    public static let coral = Color(hex: "#FF6B6B")
    public static let orange = Color(hex: "#FF8A3D")
    /// Was the old cobalt blue; the palette is red, black and white, so
    /// this is now the black accent (light grey in dark mode, so it shows).
    public static let blue = Color.dynamic(light: 0x111111, dark: 0xE5E5E5)
    /// The one real blue — an accent where it means something: water,
    /// mobility, calm breathing, a Campus unit. Never a background.
    public static let water = Color(hex: "#1CB0F6")
    public static let waterDeep = Color(hex: "#1899D6")
    /// A solid black surface with white on it (a dark grey in dark mode, so
    /// it stands out from the black background).
    public static let solid = Color.dynamic(light: 0x111111, dark: 0x2E2E2E)
    public static let purple = Color(hex: "#7C5CF2")
    public static let green = Color(hex: "#22C55E")
    public static let amber = Color(hex: "#F59E0B")
    public static let red = Color(hex: "#EF4444")

    /// One corner radius for cards, one for controls (V3: calmer, consistent).
    public static let cardCornerRadius: CGFloat = 20
    public static let controlCornerRadius: CGFloat = 14

    public static func color(for band: ReadinessBand?) -> Color {
        switch band {
        case .green: green
        case .amber: amber
        case .red: red
        case nil: secondaryText
        }
    }
}

extension Color {
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        #if os(iOS)
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
        })
        #else
        Color(rgb: dark)
        #endif
    }

    init(rgb: UInt32) {
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

#if os(iOS)
extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
#endif

// MARK: - Surfaces

public struct AppBackground: View {
    public init() {}
    public var body: some View {
        AppTheme.background.ignoresSafeArea()
    }
}

private struct CardBackground: ViewModifier {
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 3)
    }
}

public extension View {
    /// A soft card: generous corner radius, a whisper of shadow, no border.
    func cardStyle(padding: CGFloat = 16) -> some View {
        modifier(CardBackground(padding: padding))
    }

    /// The standard screen canvas, full-bleed. The status bar gets its own
    /// backdrop, so scrolled content never sits under the clock, and every
    /// scroll view ends with room to spare above the tab bar.
    func appScreen() -> some View {
        background(AppBackground())
            .overlay(alignment: .top) {
                AppTheme.background.opacity(0.96)
                    .frame(height: 0)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
            }
            .contentMargins(.bottom, 24, for: .scrollContent)
    }
}

// MARK: - Buttons

/// The primary action: a full-width red capsule, big and bold.
public struct PrimaryButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonBody(configuration: configuration)
    }

    private struct PrimaryButtonBody: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.headline.weight(.bold))
                // One line, never wrapped: shrink a little first; a row of
                // buttons that still doesn't fit stacks instead (ButtonRow).
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 18)
                .foregroundStyle(AppTheme.onAccent)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(AppTheme.accent, in: Capsule())
                .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.3)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
        }
    }
}

/// The quieter secondary action: a soft gray capsule.
public struct SecondaryButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 18)
            .foregroundStyle(AppTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(AppTheme.fill, in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Buttons side by side when every label fits on one line, stacked
/// otherwise — so big text never squeezes a label onto two lines.
public struct ButtonRow<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    public init(spacing: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: spacing) { content }
            VStack(spacing: 10) { content }
        }
    }
}

public extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

public extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

/// The floating red "+" (or a labelled capsule).
public struct FloatingActionButton: View {
    let systemImage: String
    let title: String?
    let accessibilityLabel: String
    let action: () -> Void

    /// With a `title` it's a labelled capsule, so what it does is never a guess.
    public init(systemImage: String = "plus", title: String? = nil, accessibilityLabel: String, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.title = title
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            if let title {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                    .foregroundStyle(AppTheme.onAccent)
                    .padding(.horizontal, 20)
                    .frame(height: 60)
                    .background(AppTheme.accent, in: Capsule())
                    .shadow(color: AppTheme.accent.opacity(0.35), radius: 12, x: 0, y: 6)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(AppTheme.onAccent)
                    .frame(width: 66, height: 66)
                    .background(AppTheme.accent, in: Circle())
                    .shadow(color: AppTheme.accent.opacity(0.35), radius: 12, x: 0, y: 6)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// A round gray icon button (back chevron and toolbar icons).
public struct CircleIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    public init(systemImage: String, accessibilityLabel: String, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 46, height: 46)
                .background(AppTheme.fill, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Rings

/// A progress ring with anything centred inside it.
public struct RingView<Center: View>: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat
    let center: Center

    public init(progress: Double, color: Color, lineWidth: CGFloat = 8, @ViewBuilder center: () -> Center) {
        self.progress = progress
        self.color = color
        self.lineWidth = lineWidth
        self.center = center()
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.fill, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)
            center
        }
    }
}

/// A small stat card: a bold value, a gray label, and a ring with an
/// icon underneath.
/// A home-screen widget: what it is (label and icon, with a small ring) on
/// top, the big value, then one line saying what it means. `highlight`
/// outlines a tile that's asking for the next tap (the check-in).
public struct WidgetTile: View {
    let value: String
    let label: String
    let progress: Double
    let color: Color
    let systemImage: String
    let caption: String?
    let highlight: Bool

    public init(value: String, label: String, progress: Double, color: Color, systemImage: String, caption: String? = nil, highlight: Bool = false) {
        self.value = value
        self.label = label
        self.progress = progress
        self.color = color
        self.systemImage = systemImage
        self.caption = caption
        self.highlight = highlight
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                RingView(progress: progress, color: color, lineWidth: 4) { EmptyView() }
                    .frame(width: 26, height: 26)
            }
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(2, reservesSpace: true)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .cardStyle(padding: 14)
        .overlay {
            if highlight {
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .strokeBorder(color, lineWidth: 2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)" + (caption.map { ". \($0)" } ?? ""))
    }
}

public struct RingStatCard: View {
    let value: String
    let label: String
    let progress: Double
    let color: Color
    let systemImage: String
    /// One line saying what the number means or what tapping does.
    let caption: String?

    public init(value: String, label: String, progress: Double, color: Color, systemImage: String, caption: String? = nil) {
        self.value = value
        self.label = label
        self.progress = progress
        self.color = color
        self.systemImage = systemImage
        self.caption = caption
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let caption {
                    Text(caption)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(2, reservesSpace: true)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
            RingView(progress: progress, color: color, lineWidth: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
            }
            .frame(width: 58, height: 58)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)" + (caption.map { ". \($0)" } ?? ""))
    }
}

// MARK: - Week strip

/// The row of seven day circles across the top of the home screen.
public struct WeekStrip: View {
    @Binding var selection: Date
    let marked: Set<Date>
    /// Game days get a red dot instead of the orange training one.
    let gameDays: Set<Date>

    public init(selection: Binding<Date>, marked: Set<Date>, gameDays: Set<Date> = []) {
        _selection = selection
        self.marked = marked
        self.gameDays = gameDays
    }

    private var days: [Date] {
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selection))
            ?? calendar.startOfDay(for: selection)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                dayCell(day)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let calendar = Calendar.current
        let isSelected = calendar.isDate(day, inSameDayAs: selection)
        let isToday = calendar.isDateInToday(day)
        let isMarked = marked.contains(calendar.startOfDay(for: day))
        let isGame = gameDays.contains(calendar.startOfDay(for: day))
        return Button {
            selection = day
        } label: {
            VStack(spacing: 6) {
                Text(day.formatted(.dateTime.weekday(.narrow)))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.secondaryText)
                Text(day.formatted(.dateTime.day()))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? AppTheme.onAccent : AppTheme.ink)
                    .frame(width: 36, height: 36)
                    .background {
                        if isSelected {
                            Circle().fill(AppTheme.accent)
                        } else if isToday {
                            Circle().strokeBorder(AppTheme.ink, lineWidth: 1.5)
                        } else {
                            Circle().strokeBorder(AppTheme.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                        }
                    }
                Circle()
                    .fill(isGame ? AppTheme.brand : (isMarked ? AppTheme.orange : .clear))
                    .frame(width: 5, height: 5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(date: .complete, time: .omitted) + (isGame ? ", game day" : (isMarked ? ", has training" : "")))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// What the week strip's dots mean, in words under it.
public struct WeekStripLegend: View {
    public init() {}

    public var body: some View {
        HStack(spacing: 14) {
            item(AppTheme.orange, "Workout")
            item(AppTheme.brand, "Game")
            HStack(spacing: 5) {
                Circle().strokeBorder(AppTheme.ink, lineWidth: 1.5).frame(width: 10, height: 10)
                Text("Today")
            }
            Spacer(minLength: 0)
            Text("Tap a day to see it")
        }
        .font(.caption2)
        .foregroundStyle(AppTheme.secondaryText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Orange dot: workout day. Red dot: game day. Tap a day to see its plan.")
    }

    private func item(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text)
        }
    }
}

// MARK: - Choices

/// A big rounded choice row: red when selected, soft gray when not.
public struct OptionRow: View {
    let title: String
    let subtitle: String?
    let systemImage: String?
    let isSelected: Bool

    public init(title: String, subtitle: String? = nil, systemImage: String? = nil, isSelected: Bool) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.isSelected = isSelected
    }

    public var body: some View {
        HStack(spacing: 14) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(isSelected ? AppTheme.onAccent.opacity(0.15) : AppTheme.card, in: Circle())
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.weight(.semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .opacity(0.75)
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(isSelected ? AppTheme.onAccent : AppTheme.ink)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? AppTheme.accent : AppTheme.fill, in: RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// One row of a list card (Home's TODAY, Me's settings): a tinted icon, a
/// title, one short detail, and what's on the right (a time, a tick, a chevron).
public struct ListRow<Trailing: View>: View {
    let systemImage: String
    let color: Color
    let title: String
    let detail: String?
    let trailing: Trailing

    public init(systemImage: String, color: Color = AppTheme.ink, title: String, detail: String? = nil,
                @ViewBuilder trailing: () -> Trailing = { Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.secondaryText) }) {
        self.systemImage = systemImage
        self.color = color
        self.title = title
        self.detail = detail
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .multilineTextAlignment(.leading)
                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }
}

/// A big answer for a one-tap question (check-in, reflection): the answers
/// share the width, two to a row when they don't fit on one.
public struct ChoiceGrid<Option: Hashable>: View {
    let options: [Option]
    let title: (Option) -> String
    let isSelected: (Option) -> Bool
    let onTap: (Option) -> Void

    public init(_ options: [Option], title: @escaping (Option) -> String, isSelected: @escaping (Option) -> Bool, onTap: @escaping (Option) -> Void) {
        self.options = options
        self.title = title
        self.isSelected = isSelected
        self.onTap = onTap
    }

    public var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
            ForEach(options, id: \.self) { option in
                let selected = isSelected(option)
                Button { onTap(option) } label: {
                    Text(title(option))
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(selected ? AppTheme.onAccent : AppTheme.ink)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(selected ? AppTheme.accent : AppTheme.fill,
                                    in: RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}

/// A calm one-question-at-a-time flow (check-in, reflection): close and a
/// thin progress bar on top, the question big, its answers, one button.
public struct QuestionPage<Content: View>: View {
    let progress: Double
    let question: String
    let hint: String?
    let buttonTitle: String?
    let buttonEnabled: Bool
    let onClose: () -> Void
    let onBack: (() -> Void)?
    let onButton: () -> Void
    let content: Content

    public init(progress: Double, question: String, hint: String? = nil, buttonTitle: String? = "Next", buttonEnabled: Bool = true,
                onClose: @escaping () -> Void, onBack: (() -> Void)? = nil, onButton: @escaping () -> Void = {},
                @ViewBuilder content: () -> Content) {
        self.progress = progress
        self.question = question
        self.hint = hint
        self.buttonTitle = buttonTitle
        self.buttonEnabled = buttonEnabled
        self.onClose = onClose
        self.onBack = onBack
        self.onButton = onButton
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                if let onBack {
                    CircleIconButton(systemImage: "chevron.left", accessibilityLabel: "Back", action: onBack)
                } else {
                    CircleIconButton(systemImage: "xmark", accessibilityLabel: "Close", action: onClose)
                }
                StepProgressBar(progress: progress)
            }
            .frame(minHeight: 44)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(question)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(AppTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        if let hint {
                            Text(hint)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 24)
            }
            if let buttonTitle {
                Button(buttonTitle, action: onButton)
                    .buttonStyle(.primary)
                    .disabled(!buttonEnabled)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
        }
        .appScreen()
    }
}

/// Static chips that wrap (e.g. the athlete's development goals).
struct FlowChips: View {
    let titles: [String]

    init(_ titles: [String]) {
        self.titles = titles
    }

    var body: some View {
        WrapLayout(spacing: 8) {
            ForEach(titles, id: \.self) { title in
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppTheme.fill, in: Capsule())
            }
        }
    }
}

/// A small capsule chip, for filters and 1–5 scales.
public struct Chip: View {
    let title: String
    let isSelected: Bool

    public init(_ title: String, isSelected: Bool) {
        self.title = title
        self.isSelected = isSelected
    }

    public var body: some View {
        Text(title)
            .font(.headline)
            .lineLimit(1)
            .foregroundStyle(isSelected ? AppTheme.onAccent : AppTheme.ink)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(isSelected ? AppTheme.accent : AppTheme.fill, in: Capsule())
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A small tinted label, e.g. a quality or phase name.
public struct Tag: View {
    let title: String
    let color: Color

    public init(_ title: String, color: Color = AppTheme.secondaryText) {
        self.title = title
        self.color = color
    }

    public var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: - Layout helpers

/// A screen title: very large, bold, left-aligned, inside the scroll
/// content rather than in a navigation bar.
public struct ScreenTitle: View {
    let title: String
    let subtitle: String?

    public init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // V3 type scale: page 32 bold, section 22 semibold, card 18–20,
            // body 15–17, secondary 14–15.
            Text(title)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(AppTheme.ink)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A section heading with a one-line explanation under it, so every block
/// on a screen says what it is for.
public struct SectionHeader<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let trailing: Trailing

    public init(_ title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.top, 6)
    }
}

/// A small numbered step label ("1  Check in first").
public struct StepLabel: View {
    let number: Int
    let text: String

    public init(_ number: Int, _ text: String) {
        self.number = number
        self.text = text
    }

    public var body: some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.onAccent)
                .frame(width: 22, height: 22)
                .background(AppTheme.accent, in: Circle())
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
        }
    }
}

public struct SectionTitle: View {
    let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .font(.title3.bold())
            .foregroundStyle(AppTheme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A thin capsule progress bar, as at the top of every onboarding step.
public struct StepProgressBar: View {
    let progress: Double

    public init(progress: Double) {
        self.progress = progress
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(AppTheme.fill)
                Capsule()
                    .fill(AppTheme.accent)
                    .frame(width: proxy.size.width * max(0, min(1, progress)))
                    .animation(.easeOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: 4)
        .accessibilityElement()
        .accessibilityLabel("Step progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

/// The frame every onboarding-style step uses: back button and progress bar
/// on top, a big left-aligned title, the content, and a primary button pinned
/// to the bottom.
public struct StepScaffold<Content: View>: View {
    let progress: Double?
    let title: String
    let subtitle: String?
    let buttonTitle: String
    let buttonEnabled: Bool
    let onBack: (() -> Void)?
    let onContinue: () -> Void
    let content: Content

    public init(
        progress: Double? = nil, title: String, subtitle: String? = nil,
        buttonTitle: String = "Continue", buttonEnabled: Bool = true,
        onBack: (() -> Void)? = nil, onContinue: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.progress = progress
        self.title = title
        self.subtitle = subtitle
        self.buttonTitle = buttonTitle
        self.buttonEnabled = buttonEnabled
        self.onBack = onBack
        self.onContinue = onContinue
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                if let onBack {
                    CircleIconButton(systemImage: "chevron.left", accessibilityLabel: "Back", action: onBack)
                }
                if let progress {
                    StepProgressBar(progress: progress)
                }
            }
            .frame(minHeight: 40)
            .padding(.horizontal, 24)
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ScreenTitle(title, subtitle: subtitle)
                    content
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }

            Button(buttonTitle, action: onContinue)
                .buttonStyle(.primary)
                .disabled(!buttonEnabled)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
        .appScreen()
    }
}

/// A thumbnail well: the item's pose on a gray rounded square, used in every
/// exercise list row.
public struct ItemThumbnail: View {
    let item: CatalogueItem?
    let size: CGFloat

    public init(item: CatalogueItem?, size: CGFloat = 64) {
        self.item = item
        self.size = size
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.fill)
            if let pattern = item?.posePattern {
                RigStillView(pattern: pattern)
                    .padding(4)
            } else {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title2)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Human-readable dose, e.g. "3 × 8", "3 × 20s", "2 × 10 contacts".
public enum DoseFormatter {
    /// In plain words: "3 sets of 8 reps", "2 sets of 30 seconds each side".
    public static func text(_ dose: Dose) -> String {
        let perSide = dose.perSide == true ? " each side" : ""
        let sets = dose.sets == 1 ? "1 set" : "\(dose.sets) sets"
        switch dose.kind {
        case "reps": return "\(sets) of \(dose.reps ?? 0) reps\(perSide)"
        case "time": return "\(sets) of \(duration(dose.seconds ?? 0))\(perSide)"
        case "distance": return "\(dose.sets == 1 ? "1 time" : "\(dose.sets) times") \(Int(dose.metres ?? 0)) m"
        case "contacts": return "\(sets) of \(dose.contacts ?? 0) jumps"
        default: return sets
        }
    }

    /// "30 seconds", "1 minute", "1 min 30 s".
    public static func duration(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds) seconds" }
        let m = seconds / 60, s = seconds % 60
        if s == 0 { return m == 1 ? "1 minute" : "\(m) minutes" }
        return "\(m) min \(s) s"
    }

    /// "Rest 90 seconds between sets".
    public static func rest(_ seconds: Int) -> String {
        seconds <= 0 ? "No rest needed" : "Rest \(duration(seconds)) between sets"
    }
}

/// A catalogue slug turned into a readable name when the item itself isn't
/// downloaded (e.g. a substitute from another sport's pack).
public func displayName(forSlug slug: String) -> String {
    slug.replacingOccurrences(of: "-", with: " ").capitalized
}

// MARK: - Units

/// Pounds or kilograms. Everything is stored in kg; this is only how it's
/// shown and stepped. Defaults to the phone's region (lb in the US).
public enum WeightUnit: String, Sendable, CaseIterable {
    case kg, lb

    public static let storageKey = "weightUnit"
    private static let kgPerLb = 0.45359237

    public static var current: WeightUnit {
        if let raw = UserDefaults.standard.string(forKey: storageKey), let unit = WeightUnit(rawValue: raw) { return unit }
        return Locale.current.measurementSystem == .us ? .lb : .kg
    }

    public func value(kg: Double) -> Double {
        self == .kg ? kg : kg / Self.kgPerLb
    }

    public func kg(from value: Double) -> Double {
        self == .kg ? value : value * Self.kgPerLb
    }

    /// One tap of the weight stepper, in kg.
    public var stepKg: Double {
        self == .kg ? 2.5 : 5 * Self.kgPerLb
    }

    public func format(kg: Double) -> String {
        let shown = value(kg: kg)
        let rounded = self == .lb ? shown.rounded() : (shown * 2).rounded() / 2
        return "\(rounded.formatted(.number.precision(.fractionLength(0...1)))) \(rawValue)"
    }
}
