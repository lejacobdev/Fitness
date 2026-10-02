import Foundation

/// The app side of the V6 workout engine: turns the athlete's real day —
/// sport, season, schedule, games, check-in, pain, last night's reflection,
/// the last week of training — into a TrainingDay, and asks the engine.
/// Everything the engine decides it decides here; the old patch-up layers
/// (readiness, taper, exam lightening) don't touch its sessions again.
@MainActor
enum TodayEngine {
    /// Whether the downloaded packs carry exercise profiles (V6 content).
    static func isAvailable(_ catalogue: Catalogue) -> Bool {
        catalogue.itemsBySlug.values.contains { $0.profile != nil }
    }

    static func goals() -> [Capacity] {
        let program = ProgramStore.active.map { [$0.goal] } ?? []
        var out: [Capacity] = []
        for struggle in program + Struggles.selected {
            let capacity: Capacity?
            switch struggle {
            case .acceleration: capacity = .acceleration
            case .maxSpeed: capacity = .speed
            case .agility: capacity = .coordination
            case .strength: capacity = .strength
            case .power: capacity = .power
            case .conditioning: capacity = .aerobic
            case .mobility: capacity = .mobility
            default: capacity = nil
            }
            if let capacity, !out.contains(capacity) { out.append(capacity) }
        }
        return out
    }

    static func practiceIntensity(on date: Date, calendar: Calendar = .current) -> PracticeIntensity? {
        guard PracticeSchedule.hasPractice(on: date, calendar: calendar) else { return nil }
        // That evening's reflection says how hard it was, when there is one.
        switch MindsetStore.reflection(on: date, calendar: calendar)?.hardness {
        case 4?: return .hard
        case 1?: return .light
        default: return .normal
        }
    }

    /// What a logged session trained, from its exercises' profiles.
    static func load(of session: Session, daysAgo: Int, catalogue: Catalogue) -> DayLoad {
        var capacities: [Capacity] = []
        var lower: String?
        var upper: String?
        var heavyLower = false
        var conditioningSeconds = 0
        let slugs = Array(Set(session.sets.map(\.itemSlug)))
        for slug in slugs {
            guard let item = catalogue.item(slug) else { continue }
            let p = item.planProfile
            if let top = item.qualities.max(by: { $0.value < $1.value }), top.value >= 0.7, let c = Capacity.fromQuality[top.key], !capacities.contains(c) {
                capacities.append(c)
            }
            if p.role == "primary" || p.role == "secondary" {
                if p.isLower, lower == nil { lower = ["hinge"].contains(p.pattern) ? "hinge" : "squat" }
                if p.isUpper, !p.isLower, upper == nil, ["push", "pull"].contains(p.pattern) { upper = p.pattern }
            }
            if p.isLower, p.fatigue >= 4 { heavyLower = true }
            if p.role == "conditioning" {
                conditioningSeconds += session.sets.filter { $0.itemSlug == slug }.reduce(0) { $0 + ($1.seconds ?? 30) }
            }
        }
        // A workout from Apple Health with no exercises (a run, a ride) is conditioning.
        if slugs.isEmpty { conditioningSeconds = session.minutes * 60; capacities = [.aerobic] }
        return DayLoad(daysAgo: daysAgo, capacities: capacities, lowerPattern: lower, upperPattern: upper, heavyLower: heavyLower,
                       conditioningMinutes: conditioningSeconds / 60,
                       sessionType: slugs.count >= 6 ? .gymDevelopment : slugs.isEmpty ? .conditioning : .afterPractice)
    }

    static func recentLoad(_ athlete: Athlete, sessions: [Session], catalogue: Catalogue, before date: Date,
                           calendar: Calendar = .current) -> RecentLoad {
        let today = calendar.startOfDay(for: date)
        var days: [DayLoad] = []
        for daysAgo in 1...7 {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            var load = DayLoad(daysAgo: daysAgo, practice: practiceIntensity(on: day, calendar: calendar),
                               game: athlete.competitions.contains { calendar.isDate($0.date, inSameDayAs: day) })
            for session in sessions where calendar.isDate(session.startedAt, inSameDayAs: day) {
                let logged = self.load(of: session, daysAgo: daysAgo, catalogue: catalogue)
                load.capacities = Array(Set(load.capacities + logged.capacities)).sorted { $0.rawValue < $1.rawValue }
                load.lowerPattern = load.lowerPattern ?? logged.lowerPattern
                load.upperPattern = load.upperPattern ?? logged.upperPattern
                load.heavyLower = load.heavyLower || logged.heavyLower
                load.conditioningMinutes += logged.conditioningMinutes
                load.sessionType = load.sessionType ?? logged.sessionType
            }
            days.append(load)
        }
        return RecentLoad(days: days)
    }

    /// Today (or another day this week) as the engine sees it.
    static func trainingDay(_ athlete: Athlete, sessions: [Session], catalogue: Catalogue, date: Date = .now,
                            plannedGymDay: Bool, calendar: Calendar = .current) -> TrainingDay? {
        guard let active = athlete.activeSport else { return nil }
        let sport = catalogue.sportsBySlug[active.sportSlug] ?? allSportsBySlug[active.sportSlug]
        let isToday = calendar.isDateInToday(date)
        let day = calendar.startOfDay(for: date)
        let games = athlete.competitions.map { calendar.startOfDay(for: $0.date) }
        let next = games.filter { $0 > day }.min().flatMap { calendar.dateComponents([.day], from: day, to: $0).day }
        let last = games.filter { $0 < day }.max().flatMap { calendar.dateComponents([.day], from: $0, to: day).day }

        var readiness: ReadinessLevel = .normal
        var soreLegs = false
        var pain: Set<PainArea> = []
        var reflection: ReflectionSignal?
        if isToday {
            switch DailyLoop.today(athlete)?.level {
            case .recovery?: readiness = .low
            case .reduced?: readiness = .belowNormal
            default: readiness = .normal
            }
            if let checkIn = AthleteStats.todaysCheckIn(athlete) { soreLegs = checkIn.soreness >= 5 }
            pain = TodaysPain.areas(now: date)
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: day), let last = MindsetStore.reflection(on: yesterday, calendar: calendar) {
                reflection = ReflectionSignal(dayFelt: last.hardness, bodyFelt: last.body)
            }
        }
        // Days in a row with practice, a game or a workout, up to yesterday.
        var inARow = 0
        for back in 1...10 {
            guard let d = calendar.date(byAdding: .day, value: -back, to: day) else { break }
            let busy = PracticeSchedule.hasPractice(on: d, calendar: calendar) || games.contains(d)
                || sessions.contains { calendar.isDate($0.startedAt, inSameDayAs: d) }
            if busy { inARow += 1 } else { break }
        }
        let status = isToday ? DayStatusStore.status() : .active
        let moment = PrepMoment.at(date, gameToday: games.contains(day))
        let custom = PlanCustomizationStore.load()
        return TrainingDay(
            date: date,
            phase: PhaseCalculator.phase(today: date, seasonStart: active.seasonStart, seasonEnd: active.seasonEnd),
            age: PlanGenerator.ageInYears(birthDate: athlete.birthDate, now: date),
            experience: TrainingExperience.current,
            demands: SportDemandsTable.demands(sport: sport, position: active.positionSlug),
            goals: goals(),
            practice: practiceIntensity(on: date, calendar: calendar).map { isToday ? $0 : .normal },
            gameToday: games.contains(day),
            daysToNextGame: next,
            daysSinceLastGame: last,
            readiness: readiness,
            soreLegs: soreLegs,
            painAreas: pain,
            illnessReturnDay: isToday ? IllnessReturn.day(on: date, calendar: calendar) : nil,
            examOrLongDay: ScheduleStore.isExamWeek(date, calendar: calendar) || SchoolHours.isLongDay(date, calendar: calendar),
            daysTrainedInARow: inARow,
            availableMinutes: custom.settings.effectiveMinutesPerSession,
            recent: recentLoad(athlete, sessions: sessions, catalogue: catalogue, before: date, calendar: calendar),
            reflection: reflection,
            plannedGymDay: plannedGymDay,
            travelling: status == .travel || status == .holiday,
            beforeSession: moment == .beforePractice,
            evening: moment == .evening
        )
    }

    static func kit(_ athlete: Athlete, catalogue: Catalogue, date: Date, recent: RecentLoad) -> AthleteKit {
        let active = athlete.activeSport
        let sport = active.flatMap { catalogue.sportsBySlug[$0.sportSlug] ?? allSportsBySlug[$0.sportSlug] }
        let age = PlanGenerator.ageInYears(birthDate: athlete.birthDate, now: date)
        let day = Int(date.timeIntervalSince1970 / 86_400)
        return AthleteKit(catalogue: catalogue, sport: sport, positionSlug: active?.positionSlug, formatSlug: active?.formatSlug,
                          equipment: Set(athlete.equipmentAvailable), trainsUnderCoach: athlete.trainsUnderCoach,
                          contactsLeft: TrainingExperience.current.contactCap(PlanGenerator.weeklyContactCap(age: age)),
                          seed: PlanVariant.seed("\(athlete.id)-\(day)"))
    }

    /// The session the engine builds for `type` on `date` (nil: rest, or
    /// no V6 content yet). `requested` is what the athlete opened.
    static func session(_ requested: SessionType?, athlete: Athlete, sessions: [Session], catalogue: Catalogue,
                        date: Date = .now, plannedGymDay: Bool) -> GeneratedSession? {
        guard isAvailable(catalogue),
              let day = trainingDay(athlete, sessions: sessions, catalogue: catalogue, date: date, plannedGymDay: plannedGymDay) else { return nil }
        let decision = SessionPlanner.decide(day, requested: requested)
        guard decision.sessionType != .rest else { return nil }
        var session = SessionBuilder.build(decision, day: day, kit: kit(athlete, catalogue: catalogue, date: date, recent: day.recent))
        session.slot = nil
        return session.items.isEmpty ? nil : session
    }

    /// Today's decision on its own (for Home's "why" and rest days).
    static func decision(athlete: Athlete, sessions: [Session], catalogue: Catalogue, plannedGymDay: Bool) -> (SessionDecision, TrainingDay)? {
        guard let day = trainingDay(athlete, sessions: sessions, catalogue: catalogue, plannedGymDay: plannedGymDay) else { return nil }
        return (SessionPlanner.decide(day), day)
    }

    /// The athlete's own version of a workout wins; then the engine; then the old builder.
    static func workout(_ mode: WorkoutMode, athlete: Athlete, sessions: [Session], catalogue: Catalogue,
                        context: WorkoutModeContext, plannedGymDay: Bool) -> GeneratedSession? {
        if let mine = PlanCustomizationStore.load().workout(for: .mode(mode)), !mine.items.isEmpty {
            return mine.session(date: .now, catalogue: catalogue)
        }
        let type: SessionType
        switch mode {
        case .afterPractice: type = .afterPractice
        case .gymDay: type = .gymDevelopment
        case .mobility: type = .mobility
        case .travel: type = .travel
        }
        if let built = session(type, athlete: athlete, sessions: sessions, catalogue: catalogue, plannedGymDay: plannedGymDay) {
            return built
        }
        return isAvailable(catalogue) ? nil : WorkoutModeBuilder.build(mode, context)
    }
}
