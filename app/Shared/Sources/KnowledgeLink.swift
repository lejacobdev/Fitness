import Foundation

/// The knowledge release the server publishes (GET /knowledge/release):
/// rules switched off and exercises quarantined during an incident, and
/// what experts have reviewed. Cached on the phone so it applies offline;
/// nothing works differently until the server says so.
public enum KnowledgeReleaseStore {
    static let key = "knowledge.release"

    public static var current: KnowledgeRelease {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(KnowledgeRelease.self, from: $0) } ?? KnowledgeRelease()
    }

    static func save(_ release: KnowledgeRelease) {
        UserDefaults.standard.set(try? JSONEncoder().encode(release), forKey: key)
    }

    /// Quietly does nothing offline.
    public static func refresh(baseURL: URL, session: URLSession = .shared) async {
        var request = URLRequest(url: baseURL.appending(path: "knowledge/release"))
        request.cachePolicy = .reloadIgnoringLocalCacheData
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let release = try? JSONDecoder().decode(KnowledgeRelease.self, from: data) else { return }
        save(release)
    }
}

/// "Are you ill or under a new restriction?" — the morning answer, per day.
public enum IllnessStore {
    static let key = "safety.illness"

    public static func answer(on date: Date = .now, calendar: Calendar = .current) -> IllnessAnswer? {
        let day = DayKey.of(date, calendar: calendar)
        let entries = UserDefaults.standard.stringArray(forKey: key) ?? []
        return entries.last { $0.hasPrefix(day + "=") }.flatMap { IllnessAnswer(rawValue: String($0.dropFirst(day.count + 1))) }
    }

    public static func set(_ answer: IllnessAnswer?, on date: Date = .now, calendar: Calendar = .current) {
        let day = DayKey.of(date, calendar: calendar)
        var entries = (UserDefaults.standard.stringArray(forKey: key) ?? []).filter { !$0.hasPrefix(day + "=") }
        if let answer { entries.append("\(day)=\(answer.rawValue)") }
        UserDefaults.standard.set(Array(entries.sorted().suffix(60)), forKey: key)
    }
}

extension PlanningRules {
    /// Today's planning facts for this athlete, from what the app knows.
    @MainActor
    static func context(_ athlete: Athlete, sessions: [Session], now: Date = .now, calendar: Calendar = .current) -> PlanningContext {
        var context = PlanningContext()
        let pain = PainStore.report(on: now, calendar: calendar)
        context.trainingPausedAfterHeadInjury = DayStatusStore.status(on: now, calendar: calendar) == .concussion
        context.headPainToday = pain?.involvesHead == true
        context.painToday = pain?.involvesHead == true ? nil : pain
        context.painFollowUp = PainFollowUp.pending(reports: PainStore.all(), resolvedDays: PainFollowUp.resolvedDays(), today: now, calendar: calendar)
        context.illness = IllnessStore.answer(on: now, calendar: calendar)
        context.experience = TrainingExperience.current
        context.supervised = athlete.trainsUnderCoach
        context.checkedInToday = AthleteStats.todaysCheckIn(athlete) != nil
        context.scheduleKnown = PracticeSchedule.isSet
        context.practiceToday = PracticeSchedule.hasPractice(on: now, calendar: calendar)
        let todayKey = DayKey.of(now, calendar: calendar)
        context.practiceEffort = PracticeLogStore.log(on: todayKey)?.hard
        context.practiceMinutes = PracticeSchedule.time(on: now, calendar: calendar).map { max(0, $0.end - $0.start) }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        context.competitionToday = athlete.competitions.contains { calendar.isDate($0.date, inSameDayAs: now) }
        context.competitionTomorrow = athlete.competitions.contains { calendar.isDate($0.date, inSameDayAs: tomorrow) }
        // Missing data is shown as missing, never counted as rest (§9, §23).
        let checkInDays = Set(athlete.checkIns.map { DayKey.of($0.date, calendar: calendar) })
        let sessionDays = Set(sessions.map { DayKey.of($0.startedAt, calendar: calendar) })
        let practiceDays = Set(PracticeLogStore.logs.map(\.day))
        context.daysWithoutData = (1...14).filter { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { return false }
            let key = DayKey.of(day, calendar: calendar)
            return !checkInDays.contains(key) && !sessionDays.contains(key) && !practiceDays.contains(key)
        }.count
        let gameDays = Set(athlete.competitions.map { DayKey.of($0.date, calendar: calendar) })
        var streak = 0
        for offset in 1...14 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { break }
            let key = DayKey.of(day, calendar: calendar)
            let trained = sessionDays.contains(key) || practiceDays.contains(key) || gameDays.contains(key)
                || PracticeSchedule.hasPractice(on: day, calendar: calendar)
            guard trained else { break }
            streak += 1
        }
        context.daysTrainedInARow = streak
        return context
    }

    @MainActor
    static func today(_ athlete: Athlete, sessions: [Session], now: Date = .now) -> PlanningEvaluation {
        evaluate(context(athlete, sessions: sessions, now: now), disabled: Set(KnowledgeReleaseStore.current.disabledRules))
    }
}

public extension DecisionTraceStore {
    /// Records the day's decision with the inputs that mattered.
    @MainActor
    static func record(_ evaluation: PlanningEvaluation, context: PlanningContext, selected: String, now: Date = .now) {
        var inputs: [String: String] = [
            "checkedInToday": String(context.checkedInToday),
            "practiceToday": String(context.practiceToday),
            "competitionToday": String(context.competitionToday),
            "competitionTomorrow": String(context.competitionTomorrow),
            "experience": context.experience.rawValue,
            "supervised": String(context.supervised),
        ]
        if let effort = context.practiceEffort { inputs["practiceEffort_1_5"] = String(effort) }
        if let pain = context.painToday { inputs["painToday"] = pain.areas.map(\.rawValue).joined(separator: ",") + ":" + pain.level.rawValue }
        if context.painFollowUp != nil { inputs["painRecently"] = "true" }
        if let illness = context.illness { inputs["illness"] = illness.rawValue }
        if context.trainingPausedAfterHeadInjury || context.headPainToday { inputs["headInjury"] = "true" }
        record(DecisionTrace(
            id: UUID().uuidString, day: DayKey.of(now), createdAt: now,
            knowledgeRelease: KnowledgeReleaseStore.current.release, decision: evaluation.decision,
            rules: evaluation.triggered, reasonCodes: evaluation.reasonCodes, uncertainties: evaluation.uncertainties,
            selected: selected, contentStatus: .draftRequiresExpertReview, inputs: inputs
        ))
    }
}
