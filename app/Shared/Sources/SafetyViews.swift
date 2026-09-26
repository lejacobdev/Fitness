import SwiftUI

/// Head knocks and concussion: what to do right away, the emergency signs,
/// and the step-by-step return to sport. Explains — never clears anyone.
struct ConcussionGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ConcussionGuideContent()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.semibold) }
                }
        }
    }
}

struct ConcussionGuideContent: View {
    @State private var step = ConcussionGuide.currentStep
    @State private var status = DayStatusStore.status()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenTitle("Head injury", subtitle: "What to do, and how athletes come back safely.")

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

                TrainingPauseControl(status: $status)
                Text(ConcussionGuide.source)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .containerRelativeFrame(.horizontal)
        }
        .appScreen()
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

/// Pausing all training after a head knock, and resuming once a doctor has
/// cleared the athlete.
struct TrainingPauseControl: View {
    @Binding var status: DayStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(status == .concussion ? "Training is paused." : "Hit your head? Pause all training until a doctor clears you.")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if status == .concussion {
                Button("A doctor has cleared me") {
                    DayStatusStore.set(.active, days: nil)
                    status = .active
                }
                .buttonStyle(.secondary)
            } else {
                Button("Pause training") {
                    DayStatusStore.set(.concussion, days: nil)
                    status = .concussion
                }
                .buttonStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

/// "Hit your head?" — always the same short advice.
struct HeadKnockNote: View {
    var body: some View {
        Label("Hit your head? Stop training today and tell an adult. A possible concussion needs a doctor's check.", systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.ink)
            .labelStyle(TintedIconLabelStyle(color: AppTheme.red))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous).strokeBorder(AppTheme.red, lineWidth: 1.5))
    }
}

/// After pain is reported: what the plan does and when to get help. No diagnosis.
struct PainNote: View {
    let report: PainReport
    var paused = false
    var onPause: (() -> Void)?
    let onSafety: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Pain: \(report.areas.map(\.title).joined(separator: ", ").lowercased())", systemImage: "bandage.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)
                .labelStyle(TintedIconLabelStyle(color: AppTheme.coral))
            Text("Skip anything that hurts. If it's sharp, swollen or getting worse, stop and tell a coach, athletic trainer or parent.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if report.involvesHead {
                HeadKnockNote()
                if !paused, let onPause {
                    Button("Pause training", action: onPause)
                        .buttonStyle(.secondary)
                }
            }
            Button("Safety Center", action: onSafety)
                .buttonStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

/// Safety Center: the topics, the pause after a head knock, today's pain
/// report, and the one disclaimer.
struct SafetyCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var status = DayStatusStore.status()
    @State private var pain = PainStore.report()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle("Safety Center", subtitle: "When something doesn't feel right.")
                    if status == .concussion {
                        TrainingPauseControl(status: $status)
                    }
                    if let pain {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("You reported pain today: \(pain.areas.map(\.title).joined(separator: ", ").lowercased())", systemImage: "bandage.fill")
                                .font(.headline)
                                .foregroundStyle(AppTheme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Today's training is lighter because of it.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                            Button("It's gone") {
                                PainStore.set(nil)
                                self.pain = nil
                            }
                            .buttonStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                    }
                    VStack(spacing: 0) {
                        ForEach(SafetyTopic.allCases) { topic in
                            NavigationLink {
                                if topic == .headInjury {
                                    ConcussionGuideContent()
                                } else {
                                    SafetyTopicView(topic: topic)
                                }
                            } label: {
                                ListRow(systemImage: topic.systemImage, color: topic == .headInjury || topic == .whenToStop ? AppTheme.red : AppTheme.ink,
                                        title: topic.title, detail: topic.summary)
                            }
                            .buttonStyle(.plain)
                            if topic != SafetyTopic.allCases.last {
                                Divider().padding(.leading, 54)
                            }
                        }
                    }
                    .cardStyle(padding: 12)
                    Text(SafetyTopic.disclaimer)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .appScreen()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.semibold) }
            }
            .onAppear {
                status = DayStatusStore.status()
                pain = PainStore.report()
            }
        }
    }
}

struct SafetyTopicView: View {
    let topic: SafetyTopic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenTitle(topic.title, subtitle: topic.summary)
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(topic.points, id: \.self) { point in
                        HStack(alignment: .top, spacing: 12) {
                            Circle()
                                .fill(topic == .whenToStop ? AppTheme.red : AppTheme.ink)
                                .frame(width: 7, height: 7)
                                .padding(.top, 8)
                            Text(point)
                                .font(.body)
                                .foregroundStyle(AppTheme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .appScreen()
    }
}
