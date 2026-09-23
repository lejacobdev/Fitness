import Foundation
import SwiftUI

/// §2: "Age gate at first launch, before anything else." The pure decision
/// logic is separated from the view so it is testable without a simulator —
/// a plain year subtraction is wrong right at the boundary (someone born on
/// today's date 13 years ago IS 13, not 12), so this walks whole calendar
/// years the same way `Calendar` does rather than comparing years alone.
public enum AgeGateResult: Equatable, Sendable {
    case underMinimum
    case eligible
}

public enum AgeGate {
    public static let minimumAge = 13

    public static func evaluate(birthDate: Date, now: Date = .now, calendar: Calendar = .current) -> AgeGateResult {
        let age = calendar.dateComponents([.year], from: birthDate, to: now).year ?? 0
        return age >= minimumAge ? .eligible : .underMinimum
    }
}

/// §15's first onboarding screen. A date picker, not a yes/no toggle — "a
/// yes/no gate is trivially lied past and Apple knows it." Under-13 stops
/// here entirely: §2/§23 records that under-13 support (COPPA verifiable
/// parental consent, the Kids Category) is a materially different app and
/// explicitly out of scope, so this is a hard stop, not a soft warning.
public struct AgeGateView: View {
    @State private var birthDate: Date
    private let onEligible: (Date) -> Void

    public init(onEligible: @escaping (Date) -> Void) {
        self.onEligible = onEligible
        // A sensible default so the wheel doesn't open on today's date,
        // which would read as "eligible" the instant the screen appears.
        _birthDate = State(initialValue: Calendar.current.date(byAdding: .year, value: -14, to: .now) ?? .now)
    }

    private var result: AgeGateResult {
        AgeGate.evaluate(birthDate: birthDate)
    }

    public var body: some View {
        StepScaffold(
            progress: 0.12, title: "When's your birthday?",
            subtitle: "Student Athlete is built for athletes 13 and up. We only use this to keep training age-appropriate.",
            buttonEnabled: result == .eligible, onContinue: { onEligible(birthDate) }
        ) {
            HStack(spacing: 14) {
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Student Athlete")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Text("Your sport. Your season. Your plan.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }

            DatePicker("Date of birth", selection: $birthDate, in: ...Date.now, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Date of birth")
                .cardStyle(padding: 8)

            if result == .underMinimum {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "hand.raised.fill")
                        .foregroundStyle(AppTheme.brand)
                    Text("Student Athlete is for athletes 13 and up. Come back once you turn 13.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.ink)
                }
                .cardStyle(padding: 16)
                .accessibilityLabel("You must be 13 or older to use Student Athlete")
            }

            Text("General training information, not medical advice. Talk to your coach or athletic trainer before changing how you train. Stop and tell an adult if something hurts.")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }
}

#Preview {
    AgeGateView(onEligible: { _ in })
}
