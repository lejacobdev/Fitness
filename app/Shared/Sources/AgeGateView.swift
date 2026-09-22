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
        ScrollView {
            VStack(spacing: 24) {
                Text("Student Athlete")
                    .font(.largeTitle.bold())
                Text("First, when's your birthday?")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                DatePicker(
                    "Date of birth", selection: $birthDate, in: ...Date.now, displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .accessibilityLabel("Date of birth")

                if result == .underMinimum {
                    Text("Student Athlete is for athletes 13 and up. Come back once you turn 13.")
                        .font(.callout)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .accessibilityLabel("You must be 13 or older to use Student Athlete")
                }

                Button("Continue") {
                    onEligible(birthDate)
                }
                .buttonStyle(.borderedProminent)
                .disabled(result == .underMinimum)

                Text(
                    "General training information, not medical advice. Talk to your coach or "
                    + "athletic trainer before changing how you train. Stop and tell an adult if "
                    + "something hurts."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
            .padding(24)
        }
    }
}

#Preview {
    AgeGateView(onEligible: { _ in })
}
