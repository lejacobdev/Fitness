import SwiftData
import SwiftUI

extension DailyLoop {
    /// Today's readiness for this athlete: the morning check-in (against
    /// their own normal after a week), reported pain and last night's
    /// reflection. Nil before anything is known.
    @MainActor
    static func today(_ athlete: Athlete, now: Date = .now) -> (level: TodayReadiness, reason: String)? {
        let checkIn = AthleteStats.todaysCheckIn(athlete)
        let answers = checkIn.map {
            MorningAnswers(sleepQuality: $0.sleepQuality, sleepHours: $0.sleepHours, energy: $0.energy, soreness: $0.soreness, stress: $0.stress)
        }
        return readiness(answers: answers, personalBand: checkIn?.readinessBand, pain: PainStore.report(on: now),
                         yesterday: MindsetStore.yesterdaySignal(now: now))
    }

    /// How today's training is adjusted (nil: as planned).
    @MainActor
    static func todayBand(_ athlete: Athlete) -> ReadinessBand? {
        guard let level = today(athlete)?.level, level > .normal else { return nil }
        return level.band
    }
}

/// The morning check-in (V3): about thirty seconds, one question at a time,
/// one tap each — sleep, energy, soreness, pain, mood, today's schedule —
/// then today's readiness in words. Checking in again the same day edits
/// the day's answers (one check-in per day).
struct CheckInSheet: View {
    let athlete: Athlete

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    enum Step: Hashable { case sleepHours, sleepQuality, energy, soreness, pain, painDetail, mood, schedule, result }

    @State private var step: Step = .sleepHours
    @State private var sleepHours: CheckInOption?
    @State private var sleepQuality: CheckInOption?
    @State private var energy: CheckInOption?
    @State private var soreness: CheckInOption?
    @State private var hasPain: Bool?
    @State private var painAreas: Set<PainArea> = []
    @State private var painLevel: PainLevel?
    @State private var mood: CheckInOption?
    @State private var practiceToday = PracticeSchedule.hasPractice(on: .now)
    /// Hours slept from Apple Health, when connected: pre-selects the answer.
    @State private var healthHours: Double?
    @State private var canConnectHealth = false
    @State private var dayStatus = DayStatusStore.status()
    @State private var showingSafety = false
    @State private var saveCount = 0

    init(athlete: Athlete) {
        self.athlete = athlete
        let existing = AthleteStats.todaysCheckIn(athlete)
        _sleepHours = State(initialValue: CheckInOptions.nearest(existing?.sleepHours, in: CheckInOptions.sleepHours))
        _sleepQuality = State(initialValue: CheckInOptions.nearest(existing.map { Double($0.sleepQuality) }, in: CheckInOptions.sleepQuality))
        _energy = State(initialValue: CheckInOptions.nearest(existing.map { Double($0.energy) }, in: CheckInOptions.energy))
        _soreness = State(initialValue: CheckInOptions.nearest(existing.map { Double($0.soreness) }, in: CheckInOptions.soreness))
        _mood = State(initialValue: CheckInOptions.nearest(existing.map { Double($0.stress) }, in: CheckInOptions.mood))
        let pain = PainStore.report()
        _hasPain = State(initialValue: existing == nil && pain == nil ? nil : pain != nil)
        _painAreas = State(initialValue: Set(pain?.areas ?? []))
        _painLevel = State(initialValue: pain?.level)
    }

    private var steps: [Step] {
        [.sleepHours, .sleepQuality, .energy, .soreness, .pain] + (hasPain == true ? [.painDetail] : []) + [.mood, .schedule]
    }

    private var progress: Double {
        guard let index = steps.firstIndex(of: step) else { return 1 }
        return Double(index) / Double(steps.count)
    }

    var body: some View {
        ZStack {
            page
                .id(step)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
        }
        .sensoryFeedback(.success, trigger: saveCount)
        .task {
            canConnectHealth = await HealthKitManager.shared.needsAuthorization()
            await loadHealth()
        }
        .sheet(isPresented: $showingSafety) { SafetyCenterView() }
    }

    @ViewBuilder
    private var page: some View {
        switch step {
        case .sleepHours:
            question("How long did you sleep?", hint: healthHours.map { "Apple Health: \(SleepMath.label($0))" },
                     options: CheckInOptions.sleepHours, selection: $sleepHours) {
                if canConnectHealth {
                    Button {
                        Task {
                            _ = await HealthKitManager.shared.requestAuthorization()
                            canConnectHealth = false
                            await loadHealth()
                        }
                    } label: {
                        Label("Fill in from Apple Health", systemImage: "heart.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
        case .sleepQuality:
            question("How well did you sleep?", options: CheckInOptions.sleepQuality, selection: $sleepQuality)
        case .energy:
            question("How is your energy?", options: CheckInOptions.energy, selection: $energy)
        case .soreness:
            question("How sore are you?", hint: "Normal muscle soreness from training.", options: CheckInOptions.soreness, selection: $soreness)
        case .pain:
            QuestionPage(progress: progress, question: "Any pain or discomfort?", hint: "Something that hurts — not normal soreness.",
                         buttonTitle: hasPain == nil ? nil : "Next", onClose: { dismiss() }, onBack: { back() }, onButton: { next(from: .pain) }) {
                ChoiceGrid([false, true], title: { (answer: Bool) -> String in answer ? "Yes" : "No" },
                           isSelected: { (answer: Bool) -> Bool in answer == hasPain }) { (answer: Bool) in
                    hasPain = answer
                    if !answer {
                        painAreas = []
                        painLevel = nil
                    }
                    advance(from: .pain)
                }
            }
        case .painDetail:
            QuestionPage(progress: progress, question: "Where does it hurt?", hint: "Tap every place, then how much.",
                         buttonEnabled: !painAreas.isEmpty && painLevel != nil,
                         onClose: { dismiss() }, onBack: { back() }, onButton: { next(from: .painDetail) }) {
                ChoiceGrid(PainArea.allCases, title: { (area: PainArea) -> String in area.title },
                           isSelected: { (area: PainArea) -> Bool in painAreas.contains(area) }) { (area: PainArea) in
                    if painAreas.contains(area) { painAreas.remove(area) } else { painAreas.insert(area) }
                }
                Text("How much?")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .padding(.top, 6)
                ChoiceGrid(PainLevel.allCases, title: { (level: PainLevel) -> String in level.title },
                           isSelected: { (level: PainLevel) -> Bool in level == painLevel }) { (level: PainLevel) in painLevel = level }
                if painAreas.contains(.head) {
                    HeadKnockNote()
                }
            }
        case .mood:
            question("How do you feel today?", hint: "Mood and stress — school, home, anything.", options: CheckInOptions.mood, selection: $mood)
        case .schedule:
            QuestionPage(progress: progress, question: "Today's schedule", hint: "Is this right? Your plan is built around it.",
                         buttonTitle: "Save", onClose: { dismiss() }, onBack: { back() }, onButton: { save() }) {
                if let game = athlete.competitions.first(where: { Calendar.current.isDateInToday($0.date) }) {
                    ListRow(systemImage: "sportscourt.fill", color: AppTheme.green, title: game.kind == .tournament ? "Tournament" : "Game",
                            detail: game.date.formatted(date: .omitted, time: .shortened)) { EmptyView() }
                        .cardStyle(padding: 12)
                }
                ChoiceGrid([true, false], title: { (practice: Bool) -> String in practice ? practiceLabel : "No practice today" },
                           isSelected: { (practice: Bool) -> Bool in practice == practiceToday }) { (practice: Bool) in
                    practiceToday = practice
                }
            }
        case .result:
            resultPage
        }
    }

    private var practiceLabel: String {
        if let time = PracticeSchedule.time(on: .now) { return "Practice · \(time.label)" }
        return "Team practice today"
    }

    private func question(
        _ text: String, hint: String? = nil, options: [CheckInOption], selection: Binding<CheckInOption?>
    ) -> some View {
        question(text, hint: hint, options: options, selection: selection) { EmptyView() }
    }

    private func question<Extra: View>(
        _ text: String, hint: String? = nil, options: [CheckInOption], selection: Binding<CheckInOption?>,
        @ViewBuilder extra: () -> Extra
    ) -> some View {
        let current = step
        let backAction: (() -> Void)? = current == .sleepHours ? nil : { back() }
        let buttonTitle: String? = selection.wrappedValue == nil ? nil : "Next"
        return QuestionPage(progress: progress, question: text, hint: hint, buttonTitle: buttonTitle,
                            onClose: { dismiss() }, onBack: backAction, onButton: { next(from: current) }) {
            ChoiceGrid(options, title: { (option: CheckInOption) -> String in option.title },
                       isSelected: { (option: CheckInOption) -> Bool in option == selection.wrappedValue }) { (option: CheckInOption) in
                selection.wrappedValue = option
                advance(from: current)
            }
            extra()
        }
    }

    // MARK: Moving through

    /// After a tap: a moment to see the choice, then the next question.
    private func advance(from current: Step) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            next(from: current)
        }
    }

    private func next(from current: Step) {
        guard step == current, let index = steps.firstIndex(of: current) else { return }
        if index + 1 < steps.count {
            withAnimation(.easeInOut(duration: 0.25)) { step = steps[index + 1] }
        } else {
            save()
        }
    }

    private func back() {
        guard let index = steps.firstIndex(of: step), index > 0 else { return }
        withAnimation(.easeInOut(duration: 0.2)) { step = steps[index - 1] }
    }

    private func loadHealth() async {
        healthHours = await HealthKitManager.shared.sleepHours()
        if sleepHours == nil, let healthHours {
            sleepHours = CheckInOptions.nearest(healthHours, in: CheckInOptions.sleepHours)
        }
    }

    private func save() {
        guard let sleepQuality, let energy, let soreness, let mood else { return }
        let day = DayKey.of(.now)
        // Only a day that differs from the schedule is remembered.
        PracticeOverride.set(nil, on: day)
        if practiceToday != PracticeSchedule.hasPractice(on: .now) {
            PracticeOverride.set(practiceToday, on: day)
        }
        // The exact hours from Apple Health when the answer agrees with them.
        let hours = healthHours.flatMap { CheckInOptions.nearest($0, in: CheckInOptions.sleepHours) == sleepHours ? $0 : nil } ?? sleepHours?.value
        _ = try? CheckInStore(modelContext: modelContext).submit(
            athlete: athlete, sleepQuality: sleepQuality.scale, sleepHours: hours,
            soreness: soreness.scale, energy: energy.scale, stress: mood.scale
        )
        let areas = PainArea.allCases.filter { painAreas.contains($0) }
        PainStore.set(hasPain == true && !areas.isEmpty ? PainReport(day: day, areas: areas, level: painLevel ?? .little) : nil)
        WidgetSnapshotWriter.write(for: athlete, week: WeeklyPlan.generate(for: athlete))
        saveCount += 1
        withAnimation(.easeInOut(duration: 0.25)) { step = .result }
    }

    // MARK: Result

    private var resultPage: some View {
        QuestionPage(progress: 1, question: "Today's readiness", buttonTitle: "Done", onClose: { dismiss() }, onButton: { dismiss() }) {
            if let readiness = DailyLoop.today(athlete) {
                ReadinessBlock(level: readiness.level, reason: readiness.reason)
            }
            if let pain = PainStore.report() {
                PainNote(report: pain, paused: dayStatus == .concussion, onPause: {
                    DayStatusStore.set(.concussion, days: nil)
                    dayStatus = .concussion
                }, onSafety: { showingSafety = true })
            }
        }
    }
}

/// Today's readiness in words — never a score.
struct ReadinessBlock: View {
    let level: TodayReadiness
    let reason: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Circle()
                    .fill(AppTheme.color(for: level.band))
                    .frame(width: 14, height: 14)
                Text(level.title)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
            }
            Text(reason)
                .font(.body)
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
