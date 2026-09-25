import SwiftUI

/// Head knocks and concussion: what to do right away, the emergency signs,
/// and the step-by-step return to sport. Explains — never clears anyone.
struct ConcussionGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var step = ConcussionGuide.currentStep

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle("Head knocks & concussion", subtitle: "What to do, and how athletes come back safely. Your doctor or athletic trainer makes the decisions — this helps you understand them.")

                    list("If you think you have a concussion", ConcussionGuide.rightAway, icon: "hand.raised.fill", color: AppTheme.accent)

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Get emergency help now if…", systemImage: "cross.case.fill")
                            .font(.title3.bold())
                            .foregroundStyle(AppTheme.red)
                        ForEach(ConcussionGuide.emergency, id: \.self) { sign in
                            Label(sign, systemImage: "exclamationmark.triangle.fill")
                                .font(.body)
                                .foregroundStyle(AppTheme.ink)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous).stroke(AppTheme.red, lineWidth: 2))

                    SectionHeader("Coming back, step by step", subtitle: "Tap the step your doctor or athletic trainer says you're on.")
                    ForEach(ConcussionGuide.steps, id: \.number) { item in
                        Button {
                            step = item.number
                            ConcussionGuide.currentStep = item.number
                        } label: {
                            HStack(alignment: .top, spacing: 14) {
                                Text("\(item.number)")
                                    .font(.headline)
                                    .foregroundStyle(step == item.number ? AppTheme.onAccent : AppTheme.ink)
                                    .frame(width: 36, height: 36)
                                    .background(step == item.number ? AppTheme.accent : AppTheme.fill, in: Circle())
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.ink)
                                    Text(item.what)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.ink)
                                    Text("Goal: \(item.goal)")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                                .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .cardStyle(padding: 14)
                            .overlay {
                                if step == item.number {
                                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous).stroke(AppTheme.accent, lineWidth: 2)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    list("The rules", ConcussionGuide.rules, icon: "checkmark.shield.fill", color: AppTheme.green)

                    Text("While your day status is set to “Head knock”, Athlete OS pauses every workout. Switch it back to Active once your doctor has cleared you.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text(ConcussionGuide.source)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .containerRelativeFrame(.horizontal)
            }
            .appScreen()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.semibold) }
            }
        }
    }

    private func list(_ title: String, _ lines: [String], icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(AppTheme.ink)
            ForEach(lines, id: \.self) { line in
                Label(line, systemImage: icon)
                    .font(.body)
                    .foregroundStyle(AppTheme.ink)
                    .labelStyle(TintedIconLabelStyle(color: color))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 18)
    }
}

/// A label whose icon is coloured and the text isn't.
private struct TintedIconLabelStyle: LabelStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: 10) {
            configuration.icon.foregroundStyle(color)
            configuration.title
        }
    }
}

/// "You've felt drained a lot while training hard" — kind, clear, and with
/// what to do about it.
struct LowEnergyCard: View {
    let warning: LowEnergyWarning
    var onHide: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Low energy while training hard", systemImage: "battery.25")
                .font(.title3.bold())
                .foregroundStyle(AppTheme.accent)
            Text("You've felt drained on \(warning.lowDays) of your last \(warning.checkIns) check-ins, while training on \(warning.trainingDays) of the last 14 days. That often means your body isn't getting enough food for the training — or enough sleep — and it slows progress and raises the risk of injury and illness.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(LowEnergyCheck.advice, id: \.self) { line in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.green)
                    Text(line)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let onHide {
                Button("Hide for a week", action: onHide)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous).stroke(AppTheme.accent, lineWidth: 2))
    }
}

extension LowEnergyCheck {
    /// The warning for this athlete now: check-ins, plus days with a logged
    /// workout or team practice.
    @MainActor
    static func current(for athlete: Athlete, now: Date = .now, calendar: Calendar = .current) -> LowEnergyWarning? {
        let today = calendar.startOfDay(for: now)
        var trained = Set(athlete.sessions.map { calendar.startOfDay(for: $0.startedAt) })
        for offset in 0..<windowDays {
            if let day = calendar.date(byAdding: .day, value: -offset, to: today), PracticeSchedule.hasPractice(on: day, calendar: calendar) {
                trained.insert(day)
            }
        }
        return evaluate(energies: athlete.checkIns.map { (date: $0.date, energy: $0.energy) }, trainingDays: trained, now: now, calendar: calendar)
    }
}
