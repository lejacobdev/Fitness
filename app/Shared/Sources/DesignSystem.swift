import SwiftUI

/// The app's shared visual language — dark-primary, one vibrant accent
/// color, big rounded cards ("make it look like Cal AI"). Reuses the exact
/// colors already established for the app icon (tools/generate-app-icon.py's
/// BACKDROP_TOP/BOTTOM and CHEVRON_LOWER) and the §9 muscle map's primary
/// accent (`Color(hex:)` in SVGPathParser.swift's own doc comment: "§9's
/// #E5383B primary accent") — the icon, the illustrations and the UI all
/// read as the same product rather than three unrelated ones.
public enum AppTheme {
    public static let accent = Color(hex: "#E5383B")
    public static let backgroundTop = Color(hex: "#10131A")
    public static let backgroundBottom = Color(hex: "#1D2330")
    public static let cardBackground = Color.white.opacity(0.06)
    public static let cardBorder = Color.white.opacity(0.09)

    public static let cardCornerRadius: CGFloat = 24
    public static let controlCornerRadius: CGFloat = 16
}

/// The app's full-bleed dark gradient backdrop — meant to sit behind every
/// screen's content via `.background(AppBackground())`.
public struct AppBackground: View {
    public init() {}
    public var body: some View {
        LinearGradient(
            colors: [AppTheme.backgroundTop, AppTheme.backgroundBottom],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

private struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.cardBorder, lineWidth: 1)
            )
    }
}

public extension View {
    /// A big rounded card with a soft translucent fill and hairline border —
    /// Cal AI's grouped-content look, used instead of plain lists/dividers.
    func cardStyle() -> some View {
        modifier(CardBackground())
    }
}

/// The app's one accent-filled primary button — big, bold, fully rounded
/// corners, used everywhere a screen's main action appears.
public struct AccentButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == AccentButtonStyle {
    static var accentFilled: AccentButtonStyle { AccentButtonStyle() }
}
