import SwiftUI

// MARK: - Duolingo-style palette and components

/// Campus works like Duolingo: a winding path of lessons per unit, chunky 3D
/// buttons, a lesson player with a progress bar, hearts, "Check" and a green
/// or red answer sheet. Its colours are Duolingo's own feedback colours plus
/// the app's red for the path.
enum Duo {
    static let green = Color(hex: "#58CC02")
    static let greenLip = Color(hex: "#58A700")
    static let greenSoft = Color.dynamic(light: 0xD7FFB8, dark: 0x1F3A12)
    static let greenText = Color.dynamic(light: 0x58A700, dark: 0x79D634)
    /// The selected answer and secondary buttons: black, not blue.
    static let blue = Color.dynamic(light: 0x111111, dark: 0xF2F2F2)
    static let blueLip = Color.dynamic(light: 0x000000, dark: 0xBDBDBD)
    static let blueSoft = Color.dynamic(light: 0xEBEBEB, dark: 0x262626)
    /// A black slab button with white text (dark grey in dark mode).
    static let black = AppTheme.solid
    static let blackLip = Color.dynamic(light: 0x000000, dark: 0x1A1A1A)
    static let red = Color(hex: "#FF4B4B")
    static let redLip = Color(hex: "#EA2B2B")
    static let redSoft = Color.dynamic(light: 0xFFDFE0, dark: 0x3F1E20)
    static let gold = Color(hex: "#FFC800")
    static let goldLip = Color(hex: "#E5A500")
    static let orange = Color(hex: "#FF9600")
    static let border = Color.dynamic(light: 0xE5E5E5, dark: 0x333333)
    static let lockedFill = Color.dynamic(light: 0xE5E5E5, dark: 0x333333)
    static let lockedLip = Color.dynamic(light: 0xCECECE, dark: 0x1F1F1F)
    static let lockedGlyph = Color.dynamic(light: 0xAFAFAF, dark: 0x6B6B6B)

    /// Unit colours along the path, starting with the brand red.
    static let units: [(Color, Color)] = [
        (AppTheme.brand, Color(hex: "#B8272A")), (AppTheme.water, AppTheme.waterDeep), (green, greenLip), (Color(hex: "#CE82FF"), Color(hex: "#A568CC")),
        (orange, Color(hex: "#CC7900")), (Color(hex: "#FF86D0"), Color(hex: "#CC6BA6")), (AppTheme.coral, Color(hex: "#D65454")),
    ]
}

/// A Duolingo button: a colored slab sitting on a darker lip; pressing pushes it down onto the lip.
struct ChunkyButtonStyle: ButtonStyle {
    var fill: Color = Duo.green
    var lip: Color = Duo.greenLip
    var foreground: Color = .white
    var height: CGFloat = 56

    func makeBody(configuration: Configuration) -> some View {
        ChunkyBody(configuration: configuration, fill: fill, lip: lip, foreground: foreground, height: height)
    }

    private struct ChunkyBody: View {
        let configuration: Configuration
        let fill: Color, lip: Color, foreground: Color, height: CGFloat
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let pressed = configuration.isPressed
            let top = isEnabled ? fill : Duo.lockedFill
            let under = isEnabled ? lip : Duo.lockedLip
            configuration.label
                .font(.headline.weight(.heavy))
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 16)
                .foregroundStyle(isEnabled ? foreground : Duo.lockedGlyph)
                .frame(maxWidth: .infinity, minHeight: height)
                .background(top, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .offset(y: pressed ? 4 : 0)
                .background(under.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)).offset(y: 4))
                .padding(.bottom, 4)
                .animation(.easeOut(duration: 0.08), value: pressed)
        }
    }
}

/// An answer tile: white with a gray border and lip; blue when selected, green/red once checked.
struct AnswerTile: View {
    enum State { case idle, selected, correct, wrong, done }
    let text: String
    let state: State

    var body: some View {
        let (fill, border, textColor): (Color, Color, Color) = {
            switch state {
            case .idle: (AppTheme.background, Duo.border, AppTheme.ink)
            case .selected: (Duo.blueSoft, Duo.blue, Duo.blueLip)
            case .correct: (Duo.greenSoft, Duo.green, Duo.greenText)
            case .wrong: (Duo.redSoft, Duo.red, Duo.redLip)
            case .done: (AppTheme.background, Duo.border, Duo.lockedGlyph)
            }
        }()
        Text(text)
            .font(.title3.weight(.semibold))
            .foregroundStyle(textColor)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(border, lineWidth: 2))
            .background(border.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)).offset(y: 4))
            .padding(.bottom, 4)
            .opacity(state == .done ? 0.5 : 1)
    }
}

// MARK: - Progress (XP, streak, learned lessons)

/// What Campus remembers on this device.
struct CampusProgress {
    static let learnedKey = "campus.learned"
    static let xpKey = "campus.xp"
    static let streakKey = "campus.streak"
    static let lastDayKey = "campus.lastDay"

    static func learned(_ raw: String) -> Set<String> { Set(raw.split(separator: ",").map(String.init)) }

    static func dayString(_ date: Date = .now) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    /// The streak as it stands today: it survives until a whole day is missed.
    static func currentStreak(streak: Int, lastDay: String) -> Int {
        let today = dayString(), yesterday = dayString(Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now)
        return lastDay == today || lastDay == yesterday ? streak : 0
    }

    /// XP, the streak, the week's log for leagues, and any new badges —
    /// after a lesson, a review or a sport-guide quiz.
    @MainActor
    static func earn(_ earned: Int, lesson: Bool, defaults: UserDefaults = .standard) -> [CampusBadge] {
        defaults.set(defaults.integer(forKey: xpKey) + earned, forKey: xpKey)
        var streak = defaults.integer(forKey: streakKey)
        let lastDay = defaults.string(forKey: lastDayKey) ?? ""
        let today = dayString()
        if lastDay != today {
            streak = currentStreak(streak: streak, lastDay: lastDay) + 1
            defaults.set(streak, forKey: streakKey)
            defaults.set(today, forKey: lastDayKey)
        }
        CampusLog.record(xp: earned, lesson: lesson, perfect: lesson && earned >= 15, review: !lesson, streak: streak, defaults: defaults)
        let badges = CampusBadges.award(stats(defaults), defaults: defaults)
        Task { await LeagueSync.report() }
        return badges
    }

    /// When new lessons were finished (for the free daily allowance; replays
    /// and reviews don't count). The last few only.
    static let newLessonsKey = "campus.newLessonDates"

    static func newLessonDates(_ defaults: UserDefaults = .standard) -> [Date] {
        (defaults.array(forKey: newLessonsKey) as? [Double] ?? []).map(Date.init(timeIntervalSince1970:))
    }

    static func recordNewLesson(_ date: Date = .now, _ defaults: UserDefaults = .standard) {
        let kept = (newLessonDates(defaults) + [date]).suffix(10).map(\.timeIntervalSince1970)
        defaults.set(Array(kept), forKey: newLessonsKey)
    }

    /// New lessons left today on free; nil on Pro.
    @MainActor
    static func lessonsLeftToday(_ defaults: UserDefaults = .standard) -> Int? {
        ProGate.remainingLessonsToday(isPro: ProAccess.isPro, lessonDates: newLessonDates(defaults))
    }

    static func stats(_ defaults: UserDefaults = .standard) -> CampusStats {
        let streak = currentStreak(streak: defaults.integer(forKey: streakKey), lastDay: defaults.string(forKey: lastDayKey) ?? "")
        return CampusStats(learned: learned(defaults.string(forKey: learnedKey) ?? ""), xp: defaults.integer(forKey: xpKey),
                           bestStreak: max(CampusLog.bestStreak(defaults), streak),
                           perfectLessons: CampusLog.perfectLessons(defaults), reviews: CampusLog.reviewsDone(defaults),
                           guidesPassed: SportGuideProgress.passed(defaults).count)
    }
}

/// A stable shuffle (the same order every time a question appears).
func stableOrder(_ count: Int, seed: String) -> [Int] {
    var hash: UInt64 = 5381
    for byte in seed.utf8 { hash = (hash &* 33) &+ UInt64(byte) }
    var generator = SeededGenerator(seed: String(hash))
    var order = Array(0..<count)
    for i in stride(from: count - 1, to: 0, by: -1) {
        let j = Int(generator.next() % UInt64(i + 1))
        order.swapAt(i, j)
    }
    return order
}

// MARK: - The path

struct CampusView: View {
    let athlete: Athlete
    @AppStorage(CampusProgress.learnedKey) private var learnedRaw = ""
    @AppStorage(CampusProgress.xpKey) private var xp = 0
    @AppStorage(CampusProgress.streakKey) private var streak = 0
    @AppStorage(CampusProgress.lastDayKey) private var lastDay = ""
    @State private var showingLibrary = false
    @State private var playing: CampusLesson?
    @State private var reviewing: ReviewSession?
    @State private var showingLeagues = false
    @State private var showingBadges = false
    @State private var showingGuide = false
    @State private var showingPaywall = false
    @State private var newBadges: BadgeCelebration?
    /// Bumped after a review so the due list redraws.
    @State private var revision = 0

    /// A review: questions from the lessons that are due.
    struct ReviewSession: Identifiable {
        let id = UUID()
        let lessonIDs: [String]
        let steps: [CampusStep]
    }

    private var dueForReview: [String] {
        _ = revision
        return CampusReview.due(learned: learned)
    }

    private var learned: Set<String> { CampusProgress.learned(learnedRaw) }
    private var totalLessons: Int { campusTopics.reduce(0) { $0 + $1.lessons.count } }

    /// The next lesson along the whole path — the one with the START bubble.
    private var currentLessonID: String? {
        campusTopics.flatMap(\.lessons).first { !learned.contains($0.id) && isUnlocked($0) }?.id
    }

    /// The first lesson of every unit is open; the rest open one by one.
    private func isUnlocked(_ lesson: CampusLesson) -> Bool {
        guard let topic = campusTopics.first(where: { $0.lessons.contains(lesson) }),
              let index = topic.lessons.firstIndex(of: lesson) else { return false }
        return index == 0 || learned.contains(topic.lessons[index - 1].id)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                statsBar
                ScrollView {
                    VStack(spacing: 28) {
                        SportGuideCard(athlete: athlete) { showingGuide = true }
                        dailyAllowance
                        if !dueForReview.isEmpty { reviewCard }
                        ForEach(Array(campusTopics.enumerated()), id: \.element.id) { unitIndex, topic in
                            unit(topic, index: unitIndex)
                        }
                        Text("More units are on the way.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                            .padding(.bottom, 30)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                .scrollIndicators(.hidden)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .sheet(isPresented: $showingLibrary) {
                LibraryView(athlete: athlete)
            }
            .fullScreenCover(item: $playing) { lesson in
                CampusLessonPlayer(lesson: lesson) { earned in finish(lesson, xp: earned) }
            }
            .fullScreenCover(item: $reviewing) { session in
                CampusLessonPlayer(
                    lesson: CampusLesson(id: "review", title: "Review", minutes: 3, sections: [], takeaways: []),
                    customSteps: session.steps,
                    onMistakes: { wrong in
                        let wrongLessons = Set(wrong.compactMap { CampusReview.lesson(of: $0) })
                        CampusReview.record(reviewed: session.lessonIDs, wrong: wrongLessons)
                    }
                ) { earned in finishReview(xp: earned) }
            }
            .sheet(isPresented: $showingLeagues, onDismiss: { revision += 1 }) {
                LeaguesView(stats: stats)
            }
            .sheet(isPresented: $showingBadges) {
                BadgesView()
            }
            .proPaywall(isPresented: $showingPaywall, athlete: athlete, feature: .unlimitedLessons)
            .sheet(isPresented: $showingGuide, onDismiss: { revision += 1 }) {
                SportGuideView(athlete: athlete)
            }
            .sheet(item: $newBadges) { celebration in
                BadgeCelebrationView(badges: celebration.badges)
                    .presentationDetents([.medium])
            }
            .task { await LeagueSync.report() }
        }
    }

    private var statsBar: some View {
        // One row when it fits; on narrow phones or big text the buttons
        // move under the numbers instead of squeezing them.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                statNumbers
                Spacer(minLength: 8)
                statsButtons
            }
            VStack(alignment: .leading, spacing: 4) {
                statNumbers
                HStack {
                    Spacer()
                    statsButtons
                }
            }
        }
        .font(.headline.weight(.heavy))
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Rectangle().fill(Duo.border).frame(height: 2) }
    }

    private var statNumbers: some View {
        HStack(spacing: 16) {
            Label("\(CampusProgress.currentStreak(streak: streak, lastDay: lastDay))", systemImage: "flame.fill")
                .foregroundStyle(Duo.orange)
            Label("\(xp) XP", systemImage: "bolt.fill")
                .foregroundStyle(Duo.goldLip)
            Label("\(learned.count)/\(totalLessons)", systemImage: "graduationcap.fill")
                .foregroundStyle(AppTheme.accent)
        }
        .lineLimit(1)
        .fixedSize()
    }

    private var statsButtons: some View {
        HStack(spacing: 4) {
            Button { showingLeagues = true } label: {
                Image(systemName: "trophy.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Duo.goldLip)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Leagues with your teammates")
            Button { showingBadges = true } label: {
                Image(systemName: "medal.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Duo.orange)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Your badges")
            Button { showingLibrary = true } label: {
                Image(systemName: "books.vertical.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Duo.blue)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Exercise library")
        }
        .fixedSize()
    }

    private func unit(_ topic: CampusTopic, index: Int) -> some View {
        let colors = Duo.units[index % Duo.units.count]
        return VStack(spacing: 22) {
            UnitBanner(number: index + 1, topic: topic, fill: colors.0, lip: colors.1)
            ForEach(Array(topic.lessons.enumerated()), id: \.element.id) { lessonIndex, lesson in
                let done = learned.contains(lesson.id)
                let open = isUnlocked(lesson)
                PathNode(
                    systemImage: done ? "checkmark" : (open ? "star.fill" : "lock.fill"),
                    fill: done ? Duo.gold : (open ? colors.0 : Duo.lockedFill),
                    lip: done ? Duo.goldLip : (open ? colors.1 : Duo.lockedLip),
                    glyph: open || done ? .white : Duo.lockedGlyph,
                    isCurrent: lesson.id == currentLessonID,
                    title: lesson.title
                ) {
                    // Replays are always free; new lessons have a daily allowance on free.
                    if done {
                        playing = lesson
                    } else if open {
                        if CampusProgress.lessonsLeftToday() == 0 { showingPaywall = true } else { playing = lesson }
                    }
                }
                .offset(x: pathOffset(lessonIndex))
            }
            // The unit trophy: gold once every lesson in the unit is done.
            let unitDone = topic.lessons.allSatisfy { learned.contains($0.id) }
            Image(systemName: "trophy.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(unitDone ? Duo.gold : Duo.lockedFill)
                .frame(width: 70, height: 70)
                .offset(x: pathOffset(topic.lessons.count))
                .accessibilityLabel(unitDone ? "Unit complete" : "Unit trophy, locked")
        }
    }

    /// Duolingo's winding path: nodes swing left and right.
    private func pathOffset(_ i: Int) -> CGFloat {
        [0, 44, 66, 44, 0, -44, -66, -44][i % 8]
    }

    private func finish(_ lesson: CampusLesson, xp earned: Int) {
        var set = learned
        let firstTime = !set.contains(lesson.id)
        if firstTime { CampusProgress.recordNewLesson() }
        set.insert(lesson.id)
        learnedRaw = set.sorted().joined(separator: ",")
        if firstTime { CampusReview.schedule(lesson.id) }
        earn(earned, lesson: true)
    }

    private func finishReview(xp earned: Int) {
        earn(earned, lesson: false)
        revision += 1
    }

    private func earn(_ earned: Int, lesson: Bool) {
        let badges = CampusProgress.earn(earned, lesson: lesson)
        if !badges.isEmpty { newBadges = BadgeCelebration(badges: badges) }
    }

    private var stats: CampusStats { CampusProgress.stats() }

    /// On free: how many new lessons are left today — calm, never a pop-up.
    @ViewBuilder
    private var dailyAllowance: some View {
        let _ = revision
        if let left = CampusProgress.lessonsLeftToday(), currentLessonID != nil {
            if left > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("\(left) new lesson\(left == 1 ? "" : "s") left today · replays and reviews are unlimited")
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
            } else {
                ProLockCard(feature: .unlimitedLessons, title: "That's today's \(ProLimits.freeLessonsPerDay) new lessons",
                            message: "Great work. Come back tomorrow for more, replay or review any lesson now — or keep going with unlimited lessons in Pro.")
            }
        }
    }

    /// "Review: 3 lessons" — spaced repetition keeps what was learned.
    private var reviewCard: some View {
        let due = dueForReview
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Duo.orange, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Time to review")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(AppTheme.ink)
                    Text("\(due.count) lesson\(due.count == 1 ? "" : "s") to refresh — 2 minutes keeps it in your head for good.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button("Start review") {
                let ids = Array(due.prefix(CampusReview.lessonsPerReview))
                let steps = CampusReview.questions(for: ids).map { CampusStep.question($0) }
                if !steps.isEmpty { reviewing = ReviewSession(lessonIDs: ids, steps: steps) }
            }
            .buttonStyle(ChunkyButtonStyle(fill: Duo.orange, lip: Color(hex: "#CC7900")))
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Duo.border, lineWidth: 2))
    }
}

private struct UnitBanner: View {
    let number: Int
    let topic: CampusTopic
    let fill: Color
    let lip: Color

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Unit \(number)")
                    .font(.subheadline.weight(.heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.85))
                Text(topic.title)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(topic.subtitle)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: topic.systemImage)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .background(lip.clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous)).offset(y: 5))
        .padding(.bottom, 5)
        .accessibilityElement(children: .combine)
    }
}

private struct PathNode: View {
    let systemImage: String
    let fill: Color
    let lip: Color
    let glyph: Color
    let isCurrent: Bool
    let title: String
    let action: () -> Void
    @State private var bounce = false

    var body: some View {
        VStack(spacing: 6) {
            if isCurrent {
                Text("Start")
                    .font(.subheadline.weight(.heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(fill)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Duo.border, lineWidth: 2))
                    .offset(y: bounce ? -4 : 2)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { bounce = true }
                    }
            }
            Button(action: action) {
                ZStack {
                    Ellipse().fill(lip).frame(width: 78, height: 70).offset(y: 7)
                    Ellipse().fill(fill).frame(width: 78, height: 70)
                    Image(systemName: systemImage)
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(glyph)
                }
                .frame(width: 90, height: 84)
                .overlay {
                    if isCurrent {
                        Ellipse().strokeBorder(Duo.border, lineWidth: 6).frame(width: 100, height: 92).offset(y: 3)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
        }
    }
}

// MARK: - The lesson player

struct CampusLessonPlayer: View {
    let lesson: CampusLesson
    /// A review plays questions from several lessons instead of one lesson's steps.
    var customSteps: [CampusStep]? = nil
    /// Called with the questions answered wrong at least once (for reviews).
    var onMistakes: (Set<CampusQuestion>) -> Void = { _ in }
    /// Called with the XP earned when the lesson is finished.
    let onFinish: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var queue: [CampusStep] = []
    @State private var index = 0
    @State private var completed = 0
    @State private var hearts = 5
    @State private var mistakes = 0
    @State private var phase: Phase = .answering
    @State private var choice: Int?
    @State private var fillWord: String?
    @State private var match = MatchState()
    @State private var startedAt = Date.now
    @State private var finishedAt: Date?
    @State private var feedbackTrigger = 0
    @State private var confirmQuit = false
    @State private var wrong: Set<CampusQuestion> = []

    enum Phase { case answering, correct, wrong }

    private var allSteps: [CampusStep] { customSteps ?? lesson.steps }
    private var questionCount: Int {
        allSteps.filter { if case .question = $0 { return true } else { return false } }.count
    }
    private var total: Int { allSteps.count }
    private var step: CampusStep? { queue.indices.contains(index) ? queue[index] : nil }
    private var earnedXP: Int { 10 + (mistakes == 0 ? 5 : 0) }

    var body: some View {
        VStack(spacing: 0) {
            if finishedAt != nil {
                CampusComplete(xp: earnedXP, accuracy: accuracy, seconds: Int((finishedAt ?? .now).timeIntervalSince(startedAt))) {
                    onMistakes(wrong)
                    onFinish(earnedXP)
                    dismiss()
                }
            } else if hearts == 0 {
                outOfHearts
            } else {
                header
                ScrollView {
                    Group {
                        if let step { stepView(step) }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                .scrollIndicators(.hidden)
                footer
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .onAppear { if queue.isEmpty { queue = allSteps } }
        .sensoryFeedback(trigger: feedbackTrigger) { _, _ in phase == .wrong ? .error : .success }
        .confirmationDialog("Quit this lesson?", isPresented: $confirmQuit, titleVisibility: .visible) {
            Button("Quit", role: .destructive) { dismiss() }
            Button("Keep learning", role: .cancel) {}
        } message: {
            Text("Your progress in this lesson will be lost.")
        }
    }

    private var accuracy: Int {
        let answered = questionCount + mistakes
        return answered == 0 ? 100 : Int((Double(questionCount) / Double(answered) * 100).rounded())
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button { confirmQuit = true } label: {
                Image(systemName: "xmark")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Duo.lockedGlyph)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Quit lesson")
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Duo.lockedFill)
                    Capsule().fill(Duo.green)
                        .frame(width: max(16, geo.size.width * Double(completed) / Double(max(1, total))))
                        .overlay(alignment: .top) {
                            Capsule().fill(.white.opacity(0.3)).frame(height: 5).padding(.horizontal, 8).padding(.top, 4)
                        }
                        .animation(.spring(duration: 0.4), value: completed)
                }
            }
            .frame(height: 18)
            Label("\(hearts)", systemImage: "heart.fill")
                .font(.headline.weight(.heavy))
                .foregroundStyle(Duo.red)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    @ViewBuilder
    private func stepView(_ step: CampusStep) -> some View {
        switch step {
        case .teach(let section):
            TeachCard(section: section, lessonTitle: lesson.title)
        case .question(let question):
            QuestionView(question: question, phase: phase, choice: $choice, fillWord: $fillWord, match: $match) {
                // A matching exercise checks itself once every pair is found.
                phase = .correct
                feedbackTrigger += 1
            }
            .id(index)
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch phase {
        case .answering:
            footerButton
                .padding(20)
                .overlay(alignment: .top) { Rectangle().fill(Duo.border).frame(height: 2) }
        case .correct:
            FeedbackPanel(correct: true, title: ["Nicely done!", "Great job!", "Excellent!", "You got it!"][index % 4], detail: nil) { advance() }
        case .wrong:
            FeedbackPanel(correct: false, title: "Correct answer:", detail: wrongDetail) { advance() }
        }
    }

    @ViewBuilder
    private var footerButton: some View {
        if let step {
            switch step {
            case .teach:
                Button("Continue") { advance() }
                    .buttonStyle(ChunkyButtonStyle())
            case .question(let q):
                if case .match = q {
                    // Matching needs no Check button: it checks itself.
                    Button("Check") {}.buttonStyle(ChunkyButtonStyle()).disabled(true)
                } else {
                    Button("Check") { check(q) }
                        .buttonStyle(ChunkyButtonStyle())
                        .disabled(!answerReady(q))
                }
            }
        }
    }

    private var wrongDetail: String {
        guard let step, case .question(let q) = step else { return "" }
        switch q {
        case .choice(_, let options, let answer, let explain): return "\(options[answer])\n\(explain)"
        case .trueFalse(_, let answer, let explain): return "\(answer ? "True" : "False")\n\(explain)"
        case .fill(_, _, _, let answer, let explain): return "\(answer)\n\(explain)"
        case .match: return ""
        }
    }

    private func answerReady(_ q: CampusQuestion) -> Bool {
        switch q {
        case .choice, .trueFalse: choice != nil
        case .fill: fillWord != nil
        case .match: match.isComplete
        }
    }

    private func check(_ q: CampusQuestion) {
        let right: Bool
        switch q {
        case .choice(_, _, let answer, _): right = choice == answer
        case .trueFalse(_, let answer, _): right = choice == (answer ? 0 : 1)
        case .fill(_, _, _, let answer, _): right = fillWord == answer
        case .match: right = true
        }
        phase = right ? .correct : .wrong
        if !right {
            hearts -= 1
            mistakes += 1
            wrong.insert(q)
            // Duolingo brings a missed exercise back at the end of the lesson.
            queue.append(queue[index])
        }
        feedbackTrigger += 1
    }

    private func advance() {
        if phase != .wrong { completed = min(total, completed + 1) }
        phase = .answering
        choice = nil
        fillWord = nil
        match = MatchState()
        if index + 1 < queue.count {
            index += 1
        } else {
            completed = total
            finishedAt = .now
        }
    }

    private var outOfHearts: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "heart.slash.fill")
                .font(.system(size: 80, weight: .bold))
                .foregroundStyle(Duo.red)
            Text("You ran out of hearts")
                .font(.title.weight(.heavy))
                .foregroundStyle(AppTheme.ink)
            Text("No problem — go through the lesson again. Every try makes it stick.")
                .font(.title3)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Try again") {
                queue = allSteps
                wrong = []
                index = 0; completed = 0; hearts = 5; mistakes = 0; phase = .answering
                choice = nil; fillWord = nil; match = MatchState(); startedAt = .now
            }
            .buttonStyle(ChunkyButtonStyle(fill: Duo.black, lip: Duo.blackLip))
            Button("Quit") { dismiss() }
                .font(.headline.weight(.heavy))
                .textCase(.uppercase)
                .foregroundStyle(Duo.blue)
                .frame(height: 50)
        }
        .padding(24)
    }
}

/// A teaching card: the coach explains one idea in a speech bubble.
private struct TeachCard: View {
    let section: CampusSection
    let lessonTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(lessonTitle)
                .font(.subheadline.weight(.heavy))
                .textCase(.uppercase)
                .foregroundStyle(Duo.blue)
            Text(section.heading)
                .font(.largeTitle.weight(.heavy))
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "figure.run")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(AppTheme.onAccent)
                    .frame(width: 60, height: 60)
                    .background(AppTheme.accent, in: Circle())
                Text(section.body)
                    .font(.title3)
                    .foregroundStyle(AppTheme.ink)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(16)
                    .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Duo.border, lineWidth: 2))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Matching state: which left/right tiles are picked, which pairs are found, and a brief wrong flash.
struct MatchState: Equatable {
    var left: Int?
    var right: Int?
    var matched: Set<Int> = []
    var wrong: [Int] = []
    var pairCount = 0
    var isComplete: Bool { pairCount > 0 && matched.count == pairCount }
}

private struct QuestionView: View {
    let question: CampusQuestion
    let phase: CampusLessonPlayer.Phase
    @Binding var choice: Int?
    @Binding var fillWord: String?
    @Binding var match: MatchState
    let onMatched: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            switch question {
            case .choice(let prompt, let options, let answer, _):
                title("Choose the right answer")
                Text(prompt).font(.title2.weight(.bold)).foregroundStyle(AppTheme.ink).fixedSize(horizontal: false, vertical: true)
                let order = stableOrder(options.count, seed: prompt)
                VStack(spacing: 12) {
                    ForEach(order, id: \.self) { i in
                        tile(options[i], index: i, answer: answer)
                    }
                }
            case .trueFalse(let statement, let answer, _):
                title("True or false?")
                Text(statement).font(.title2.weight(.bold)).foregroundStyle(AppTheme.ink).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    tile("True", index: 0, answer: answer ? 0 : 1)
                    tile("False", index: 1, answer: answer ? 0 : 1)
                }
            case .fill(let before, let after, let options, let answer, _):
                title("Fill in the blank")
                sentence(before: before, after: after)
                let order = stableOrder(options.count, seed: before)
                WrapRow(items: order.map { options[$0] }) { word in
                    Button {
                        guard phase == .answering else { return }
                        fillWord = fillWord == word ? nil : word
                    } label: {
                        AnswerTile(text: word, state: fillWord == word ? (phase == .answering ? .done : (word == answer ? .correct : .wrong)) : .idle)
                            .fixedSize()
                    }
                    .buttonStyle(.plain)
                }
            case .match(let prompt, let pairs):
                title(prompt)
                matchGrid(pairs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .font(.title.weight(.heavy))
            .foregroundStyle(AppTheme.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func tile(_ text: String, index: Int, answer: Int) -> some View {
        let state: AnswerTile.State = {
            if phase == .answering { return choice == index ? .selected : .idle }
            if index == answer { return .correct }
            return choice == index ? .wrong : .idle
        }()
        return Button {
            if phase == .answering { choice = index }
        } label: {
            AnswerTile(text: text, state: state)
        }
        .buttonStyle(.plain)
    }

    private func sentence(before: String, after: String) -> some View {
        let blank = fillWord ?? "        "
        return (Text(before + " ") + Text(blank).underline().foregroundColor(Duo.blueLip).bold() + Text(" " + after))
            .font(.title2.weight(.semibold))
            .foregroundStyle(AppTheme.ink)
            .lineSpacing(10)
            .fixedSize(horizontal: false, vertical: true)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Duo.border, lineWidth: 2))
    }

    private func matchGrid(_ pairs: [[String]]) -> some View {
        let rightOrder = stableOrder(pairs.count, seed: pairs.map { $0.first ?? "" }.joined())
        return HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 12) {
                ForEach(0..<pairs.count, id: \.self) { i in
                    matchTile(pairs[i].first ?? "", pair: i, isLeft: true)
                }
            }
            VStack(spacing: 12) {
                ForEach(rightOrder, id: \.self) { i in
                    matchTile(pairs[i].last ?? "", pair: i, isLeft: false)
                }
            }
        }
        .onAppear { if match.pairCount == 0 { match.pairCount = pairs.count } }
    }

    private func matchTile(_ text: String, pair: Int, isLeft: Bool) -> some View {
        let picked = isLeft ? match.left == pair : match.right == pair
        let state: AnswerTile.State = match.matched.contains(pair) ? .done
            : (match.wrong.contains(pair) ? .wrong : (picked ? .selected : .idle))
        return Button {
            guard !match.matched.contains(pair) else { return }
            if isLeft { match.left = pair } else { match.right = pair }
            guard let l = match.left, let r = match.right else { return }
            if l == r {
                match.matched.insert(l)
                match.left = nil; match.right = nil
                if match.isComplete { onMatched() }
            } else {
                match.wrong = [l, r]
                match.left = nil; match.right = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { match.wrong = [] }
            }
        } label: {
            AnswerTile(text: text, state: state)
        }
        .buttonStyle(.plain)
        .disabled(match.matched.contains(pair))
    }
}

/// A simple wrapping row for word-bank chips.
private struct WrapRow<Content: View>: View {
    let items: [String]
    let content: (String) -> Content

    var body: some View {
        WrapLayout(spacing: 10) {
            ForEach(items, id: \.self) { content($0) }
        }
    }
}

struct WrapLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width == .infinity ? x : width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// The green or red sheet that slides up after "Check".
private struct FeedbackPanel: View {
    let correct: Bool
    let title: String
    let detail: String?
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 34, weight: .bold))
                Text(title)
                    .font(.title2.weight(.heavy))
            }
            .foregroundStyle(correct ? Duo.greenText : Duo.redLip)
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(correct ? Duo.greenText : Duo.redLip)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(correct ? "Continue" : "Got it", action: onContinue)
                .buttonStyle(ChunkyButtonStyle(fill: correct ? Duo.green : Duo.red, lip: correct ? Duo.greenLip : Duo.redLip))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(correct ? Duo.greenSoft : Duo.redSoft)
        .transition(.move(edge: .bottom))
    }
}

/// "Lesson complete!" with the XP, accuracy and time boxes.
private struct CampusComplete: View {
    let xp: Int
    let accuracy: Int
    let seconds: Int
    let onContinue: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            Image(systemName: "star.circle.fill")
                .font(.system(size: 110, weight: .bold))
                .foregroundStyle(Duo.gold)
                .scaleEffect(appeared ? 1 : 0.4)
                .animation(.spring(response: 0.5, dampingFraction: 0.5), value: appeared)
            Text("Lesson complete!")
                .font(.largeTitle.weight(.heavy))
                .foregroundStyle(Duo.goldLip)
            HStack(spacing: 12) {
                stat("Total XP", "\(xp)", systemImage: "bolt.fill", color: Duo.gold)
                stat(accuracy >= 80 ? "Amazing" : "Accuracy", "\(accuracy)%", systemImage: "target", color: Duo.green)
                stat("Time", String(format: "%d:%02d", seconds / 60, seconds % 60), systemImage: "stopwatch.fill", color: Duo.blue)
            }
            Spacer()
            Button("Continue", action: onContinue)
                .buttonStyle(ChunkyButtonStyle())
        }
        .padding(24)
        .onAppear { appeared = true }
        .sensoryFeedback(.success, trigger: appeared)
    }

    private func stat(_ label: String, _ value: String, systemImage: String, color: Color) -> some View {
        VStack(spacing: 0) {
            Text(label)
                .font(.caption.weight(.heavy))
                .textCase(.uppercase)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            Label(value, systemImage: systemImage)
                .font(.title3.weight(.heavy))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(3)
        }
        .background(color, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
