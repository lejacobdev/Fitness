import SwiftUI

/// Which sports' drills an athlete sees anywhere in the app. Free covers one
/// sport: only the active sport's drills (plus general exercises) — other
/// sports' drills stay hidden until the athlete switches. Pro sees the drills
/// of every sport they play. Never a sport they don't play.
enum SportVisibility {
    struct Sport: Equatable, Sendable {
        let slug: String
        let position: String?
        let format: String?
    }

    static func sports(active: Sport?, all: [Sport], isPro: Bool) -> [Sport] {
        guard isPro else { return active.map { [$0] } ?? [] }
        return all.isEmpty ? (active.map { [$0] } ?? []) : all
    }

    /// A general exercise, or a drill that fits one of the visible sports
    /// (and that sport's position and format).
    static func isVisible(_ item: CatalogueItem, sports: [Sport]) -> Bool {
        if item.itemSportSlug == nil, item.positions == nil, item.formats == nil { return true }
        return sports.contains { item.fits(sport: $0.slug, position: $0.position, format: $0.format) }
    }

    @MainActor
    static func sports(for athlete: Athlete) -> [Sport] {
        let sport = { (s: AthleteSport) in Sport(slug: s.sportSlug, position: s.positionSlug, format: s.formatSlug) }
        return sports(active: athlete.activeSport.map(sport), all: athlete.sortedSports.map(sport), isPro: ProAccess.isPro)
    }
}

/// Where a search result goes.
enum AppSearchTarget: Hashable {
    // Home
    case checkIn, logWorkout, addGame, history, fuel, dayStatus, schedule, reflection, today, safety, mindset, tests
    case breathing, visualization, practiceLog
    // Sections
    case tab(AppTab)
    // Settings and tools (Me, Workout, Campus)
    case sports, season, equipment, experience, name, reports, checkIns, exerciseProgress, dataExport
    case reminders, downloads, health, help, team, coach, parent, goals, trends, library, sportGuide
    case leagues, badges, newGymPlan, upgrade
    // Content
    case workoutMode(WorkoutMode)
    case gymDay(Int)
    case myWorkout(UUID)
    case lesson(String)
}

struct AppSearchEntry: Identifiable {
    enum Section: String, CaseIterable {
        case functions = "In the app"
        case workouts = "Workouts"
        case lessons = "Campus lessons"
    }

    let id: String
    let section: Section
    let title: String
    let detail: String
    let systemImage: String
    let keywords: [String]
    let target: AppSearchTarget

    var fields: [FuzzySearch.Field] {
        [FuzzySearch.Field(title, weight: 3), FuzzySearch.Field(keywords, weight: 1.5), FuzzySearch.Field(detail, weight: 1, fuzzy: false)]
    }
}

enum AppSearch {
    private static func function(_ title: String, _ detail: String, _ icon: String, _ keywords: [String], _ target: AppSearchTarget) -> AppSearchEntry {
        AppSearchEntry(id: "fn." + title, section: .functions, title: title, detail: detail, systemImage: icon, keywords: keywords, target: target)
    }

    /// Everything the app can do, in the words athletes use for it.
    static var functions: [AppSearchEntry] { [
        function("Morning check-in", "Sleep, energy, soreness, pain, mood", "sun.max.fill", ["readiness", "sleep", "energy", "sore", "soreness", "pain", "mood", "stress", "morning"], .checkIn),
        function("Log a workout", "Start an empty workout and log sets", "plus.circle.fill", ["log", "record", "track", "sets", "reps", "weights", "start", "workout"], .logWorkout),
        function("Log practice", "How practice went, effort and mood", "person.3.fill", ["practice", "team", "training", "effort", "mood", "log"], .practiceLog),
        function("Add a game", "Games, tournaments and meets", "sportscourt.fill", ["game", "match", "tournament", "meet", "competition", "race", "event"], .addGame),
        function("Past workouts", "Training History", "clock.arrow.circlepath", ["history", "past", "logged", "sessions", "training history"], .history),
        function("Food & water", "Fuel for practice and games", "fork.knife", ["food", "eat", "meal", "nutrition", "water", "drink", "hydration", "fuel", "protein"], .fuel),
        function("Kind of day", "Normal, sick, travel, holiday", "calendar.day.timeline.left", ["sick", "ill", "travel", "holiday", "vacation", "rest", "status", "day"], .dayStatus),
        function("Practice schedule", "Practice days and times", "calendar.badge.clock", ["schedule", "practice", "times", "days", "calendar", "team"], .schedule),
        function("Evening reflection", "How today went", "moon.stars.fill", ["reflect", "reflection", "evening", "journal", "diary", "went well"], .reflection),
        function("Today's checklist", "What's done today and what's left", "checklist", ["today", "done", "completed", "checklist", "progress"], .today),
        function("Safety Center", "Pain, head injury, illness", "cross.case.fill", ["safety", "injury", "hurt", "pain", "concussion", "head", "doctor", "sick"], .safety),
        function("Mindset", "Goals, confidence and routines", "brain.head.profile", ["mindset", "mental", "confidence", "nerves", "focus", "pressure"], .mindset),
        function("Breathing", "2 minutes to calm down", "wind", ["breathing", "breathe", "calm", "relax", "nerves", "anxiety", "stress"], .breathing),
        function("Visualization", "See your game before you play", "eye.fill", ["visualize", "visualization", "imagery", "mental", "game"], .visualization),
        function("Tests", "Sprint, jump and other benchmarks", "stopwatch.fill", ["test", "benchmark", "sprint", "jump", "speed", "measure", "personal best", "pb"], .tests),
        function("Home", "Today at a glance", "house.fill", ["home", "today", "overview"], .tab(.today)),
        function("Campus", "Lessons about training, food, sleep and mind", "graduationcap.fill", ["campus", "learn", "lessons", "school", "course"], .tab(.campus)),
        function("Workout", "After practice, gym day, mobility, travel", "figure.strengthtraining.traditional", ["workout", "train", "gym", "plan", "exercise"], .tab(.workout)),
        function("Progress", "Calendar, practice log and events", "calendar", ["progress", "calendar", "week", "month", "stats"], .tab(.progress)),
        function("Me", "Profile and settings", "person.fill", ["me", "profile", "settings", "account"], .tab(.me)),
        function("Sports", "Switch, change or add a sport", "sportscourt.fill", ["sport", "sports", "position", "switch", "change", "add"], .sports),
        function("Season dates", "When your season starts and ends", "calendar", ["season", "dates", "off-season", "in-season", "preseason"], .season),
        function("Equipment", "What you can train with", "dumbbell.fill", ["equipment", "gym", "weights", "dumbbells", "bands", "bodyweight", "barbell"], .equipment),
        function("Training experience", "Beginner, intermediate, experienced", "figure.strengthtraining.traditional", ["experience", "level", "beginner", "advanced", "lifting"], .experience),
        function("Your name", "How the app greets you", "person.text.rectangle", ["name", "profile"], .name),
        function("Development Goals", "What you want to get better at", "target", ["goals", "improve", "weakness", "struggles", "development"], .goals),
        function("New gym plan", "Generate one or build your own", "arrow.clockwise", ["new plan", "gym plan", "generate", "randomize", "build", "change plan"], .newGymPlan),
        function("Exercise library", "Every exercise and drill, animated", "books.vertical.fill", ["library", "exercises", "drills", "catalogue", "browse", "how to"], .library),
        function("Sport guide", "Know your sport and position", "book.fill", ["guide", "rules", "position", "sport", "know"], .sportGuide),
        function("Leagues", "Weekly Campus leagues with friends", "trophy.fill", ["league", "leagues", "friends", "compete", "xp", "leaderboard"], .leagues),
        function("Badges", "What you've earned", "rosette", ["badges", "awards", "achievements"], .badges),
        function("Trends", "Sleep, load and balance over time", "chart.xyaxis.line", ["trends", "charts", "sleep", "load", "balance", "graph"], .trends),
        function("Exercise progress", "Charts for every exercise", "chart.line.uptrend.xyaxis", ["progress", "charts", "strength", "weights", "exercise"], .exerciseProgress),
        function("Past check-ins", "Every morning check-in", "sun.max.fill", ["check-ins", "history", "sleep", "readiness"], .checkIns),
        function("Reports", "Season report, PDF, recruiting", "doc.richtext", ["report", "pdf", "recruiting", "college", "coach", "season card"], .reports),
        function("Export my data", "Download everything as JSON", "square.and.arrow.up", ["export", "data", "download", "json", "backup"], .dataExport),
        function("Reminders", "Check-in, bedtime and water reminders", "bell.fill", ["reminders", "notifications", "alerts", "bedtime", "water"], .reminders),
        function("Downloads for offline use", "Sports and animations on this phone", "arrow.down.circle.fill", ["offline", "downloads", "packs", "storage"], .downloads),
        function("Apple Health", "Sleep, heart rate and workouts", "heart.fill", ["health", "apple health", "healthkit", "heart rate", "watch", "sleep"], .health),
        function("My team", "Join your team with a code", "person.3.fill", ["team", "join", "code", "teammates"], .team),
        function("Coach mode", "For coaches", "whistle.fill", ["coach", "team", "athletes", "assign"], .coach),
        function("Parent summary", "A weekly summary for parents", "house.fill", ["parent", "parents", "family", "summary"], .parent),
        function("Help & app tour", "How the app works", "questionmark.circle.fill", ["help", "tour", "faq", "support", "how"], .help),
        function("AthleteOS Pro", "What Pro adds", "star.fill", ["pro", "upgrade", "subscription", "premium", "pay"], .upgrade),
    ] }

    static func workoutModes() -> [AppSearchEntry] {
        let modes: [(mode: WorkoutMode, icon: String, detail: String, keywords: [String])] = [
            (.afterPractice, "bolt.fill", "Short strength and injury prevention", ["after practice", "short", "strength", "prevention"]),
            (.gymDay, "dumbbell.fill", "Your main strength and power session", ["gym", "strength", "power", "weights", "lifting"]),
            (.mobility, "figure.flexibility", "Mobility, stretching and breathing", ["mobility", "stretch", "stretching", "warm-up", "movement prep", "flexibility", "yoga"]),
            (.travel, "suitcase.fill", "No equipment, anywhere", ["travel", "hotel", "home", "bodyweight", "no equipment"]),
        ]
        return modes.map { entry in
            AppSearchEntry(id: "mode.\(entry.mode.rawValue)", section: .workouts, title: entry.mode.title, detail: entry.detail,
                           systemImage: entry.icon, keywords: entry.keywords + ["workout", "train"], target: .workoutMode(entry.mode))
        }
    }

    static func gymDays(_ week: GeneratedWeek?) -> [AppSearchEntry] {
        (week?.sessions ?? []).enumerated().map { index, session in
            AppSearchEntry(id: "gym.\(index)", section: .workouts, title: "Gym day \(index + 1): \(session.title)",
                           detail: "\(session.date.formatted(.dateTime.weekday(.wide))) · \(session.estimatedMinutes) min",
                           systemImage: "dumbbell.fill", keywords: ["gym", "plan", "week", "session"], target: .gymDay(index))
        }
    }

    static func myWorkouts(_ workouts: [CustomWorkout]) -> [AppSearchEntry] {
        workouts.map { workout in
            AppSearchEntry(id: "mine.\(workout.id)", section: .workouts, title: workout.title, detail: "Your workout · \(workout.items.count) exercises",
                           systemImage: "star.fill", keywords: ["my workout", "own", "custom", "saved"], target: .myWorkout(workout.id))
        }
    }

    /// Lessons the athlete can open now: done ones, and the next of each unit.
    static func lessons(learned: Set<String>) -> [AppSearchEntry] {
        campusTopics.flatMap { topic in
            topic.lessons.enumerated().compactMap { index, lesson -> AppSearchEntry? in
                let done = learned.contains(lesson.id)
                guard done || index == 0 || learned.contains(topic.lessons[index - 1].id) else { return nil }
                return AppSearchEntry(id: "lesson.\(lesson.id)", section: .lessons, title: lesson.title,
                                      detail: "\(topic.title) · \(lesson.minutes) min\(done ? " · done" : "")",
                                      systemImage: "graduationcap.fill", keywords: [topic.title, topic.subtitle], target: .lesson(lesson.id))
            }
        }
    }

    static func rank(_ entries: [AppSearchEntry], query: String) -> [AppSearchEntry] {
        FuzzySearch.rank(entries, query: query) { $0.fields }
    }
}

/// Opening a Campus lesson from outside Campus (the search on Home).
@MainActor
@Observable
final class CampusLaunch {
    static let shared = CampusLaunch()
    var pendingLessonID: String?
    private init() {}
}

/// Home → search: every function, workout, lesson and exercise the athlete
/// has right now. Exercises follow `SportVisibility` (free: the active
/// sport's drills only).
struct AppSearchSheet: View {
    let entries: [AppSearchEntry]
    let exercises: [CatalogueItem]
    let onPick: (AppSearchTarget) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @FocusState private var focused: Bool

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var hits: [AppSearchEntry] { trimmed.isEmpty ? [] : AppSearch.rank(entries, query: trimmed) }
    private var exerciseHits: [CatalogueItem] {
        trimmed.isEmpty ? [] : Array(CatalogueSearch.rank(exercises, query: trimmed).prefix(30))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    field
                    if trimmed.isEmpty {
                        suggestions
                    } else if hits.isEmpty && exerciseHits.isEmpty {
                        Text("Nothing found for \"\(trimmed)\".")
                            .font(.body)
                            .foregroundStyle(AppTheme.secondaryText)
                            .padding(.top, 8)
                    } else {
                        ForEach(AppSearchEntry.Section.allCases, id: \.self) { section in
                            let rows = hits.filter { $0.section == section }.prefix(section == .functions ? 12 : 8)
                            if !rows.isEmpty {
                                group(section.rawValue) {
                                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, entry in
                                        entryRow(entry)
                                        if index < rows.count - 1 { Divider().padding(.leading, 54) }
                                    }
                                }
                            }
                        }
                        if !exerciseHits.isEmpty {
                            group("Exercises & drills") {
                                ForEach(Array(exerciseHits.enumerated()), id: \.element.slug) { index, item in
                                    NavigationLink {
                                        ItemDetailView(item: item)
                                    } label: {
                                        LibraryRow(item: item)
                                    }
                                    .buttonStyle(.plain)
                                    if index < exerciseHits.count - 1 { Divider() }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .appScreen()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .onAppear { focused = true }
        }
    }

    private var field: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.secondaryText)
            TextField("Search AthleteOS", text: $query)
                .font(.body)
                .foregroundStyle(AppTheme.ink)
                .focused($focused)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(AppTheme.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))
    }

    /// Before typing: the things people look for most.
    private var suggestions: some View {
        let common: [AppSearchTarget] = [.checkIn, .logWorkout, .newGymPlan, .library, .fuel, .safety]
        let rows = common.compactMap { target in entries.first { $0.target == target } }
        return group("Popular") {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, entry in
                entryRow(entry)
                if index < rows.count - 1 { Divider().padding(.leading, 54) }
            }
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(AppTheme.secondaryText)
            VStack(spacing: 0) { content() }
                .cardStyle(padding: 12)
        }
    }

    private func entryRow(_ entry: AppSearchEntry) -> some View {
        Button { onPick(entry.target) } label: {
            ListRow(systemImage: entry.systemImage, color: AppTheme.ink, title: entry.title, detail: entry.detail)
                .frame(minHeight: 52)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
