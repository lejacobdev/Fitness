import Foundation
import SwiftUI

/// What the season report, the PDF and the recruiting profile show — built
/// from the athlete's own data, pure so it can be tested.
public struct AthleteReport: Sendable, Equatable {
    public struct TestLine: Sendable, Equatable, Identifiable {
        public let name: String
        public let best: String
        public let change: String?
        public var id: String { name }
    }

    public var name: String?
    public var sport: String
    public var position: String?
    public var age: Int
    public var from: Date
    public var to: Date
    public var workouts: Int
    public var minutes: Int
    public var practices: Int
    public var checkIns: Int
    public var averageSleep: Double?
    public var lessons: Int
    public var longestStreak: Int
    public var tests: [TestLine]
    public var topExercise: String?

    public struct Input: Sendable {
        public var name: String?
        public var sport: String
        public var position: String?
        public var age: Int
        public var sessionDates: [Date]
        public var sessionMinutes: [Int]
        public var exerciseNames: [String]
        public var practiceDays: [String]
        public var checkInDates: [Date]
        public var sleepHours: [Double]
        public var lessons: Int
        public var results: [BenchmarkResult]
        public var tests: [BenchmarkTest]

        public init(name: String?, sport: String, position: String?, age: Int, sessionDates: [Date], sessionMinutes: [Int],
                    exerciseNames: [String], practiceDays: [String], checkInDates: [Date], sleepHours: [Double], lessons: Int,
                    results: [BenchmarkResult], tests: [BenchmarkTest]) {
            self.name = name
            self.sport = sport
            self.position = position
            self.age = age
            self.sessionDates = sessionDates
            self.sessionMinutes = sessionMinutes
            self.exerciseNames = exerciseNames
            self.practiceDays = practiceDays
            self.checkInDates = checkInDates
            self.sleepHours = sleepHours
            self.lessons = lessons
            self.results = results
            self.tests = tests
        }
    }

    public static func make(_ input: Input, from: Date, to: Date, calendar: Calendar = .current) -> AthleteReport {
        let inRange = { (date: Date) in date >= from && date <= to }
        let sessions = zip(input.sessionDates, input.sessionMinutes).filter { inRange($0.0) }
        let fromKey = DayKey.of(from, calendar: calendar)
        let toKey = DayKey.of(to, calendar: calendar)
        let practices = input.practiceDays.filter { $0 >= fromKey && $0 <= toKey }.count
        let checkInDays = input.checkInDates.filter(inRange).map { calendar.startOfDay(for: $0) }
        let streak = longestRun(Set(checkInDays + input.sessionDates.filter(inRange).map { calendar.startOfDay(for: $0) }), calendar: calendar)
        let counts = Dictionary(input.exerciseNames.map { ($0, 1) }, uniquingKeysWith: +)
        let top = counts.max { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }?.key

        let tests = input.tests.compactMap { test -> TestLine? in
            let mine = input.results.filter { $0.testID == test.id && inRange($0.date) }.sorted { $0.date < $1.date }
            guard let best = BenchmarkMath.best(mine, test: test), let first = mine.first else { return nil }
            let delta = best.value - first.value
            let change = mine.count > 1 && delta != 0 ? test.unit.formatChange(delta, higherIsBetter: test.higherIsBetter) : nil
            return TestLine(name: test.name, best: test.unit.format(best.value), change: change)
        }

        return AthleteReport(
            name: input.name, sport: input.sport, position: input.position, age: input.age, from: from, to: to,
            workouts: sessions.count, minutes: sessions.reduce(0) { $0 + $1.1 }, practices: practices,
            checkIns: Set(checkInDays).count,
            averageSleep: input.sleepHours.isEmpty ? nil : input.sleepHours.reduce(0, +) / Double(input.sleepHours.count),
            lessons: input.lessons, longestStreak: streak, tests: tests, topExercise: top
        )
    }

    static func longestRun(_ days: Set<Date>, calendar: Calendar) -> Int {
        var best = 0
        for day in days {
            guard let before = calendar.date(byAdding: .day, value: -1, to: day), !days.contains(before) else { continue }
            var length = 1
            var next = day
            for _ in 0..<400 {
                guard let following = calendar.date(byAdding: .day, value: 1, to: next), days.contains(following) else { break }
                length += 1
                next = following
            }
            best = max(best, length)
        }
        return best
    }
}

/// The recruiting profile's own details (Pro), kept on the phone and in
/// the athlete's backup. Nothing here is required.
public struct RecruitingDetails: Codable, Sendable, Equatable {
    public var graduationYear: Int?
    public var heightCm: Int?
    public var school: String?
    public var highlights: String?

    public init(graduationYear: Int? = nil, heightCm: Int? = nil, school: String? = nil, highlights: String? = nil) {
        self.graduationYear = graduationYear
        self.heightCm = heightCm
        self.school = school
        self.highlights = highlights
    }

    static let key = "profile.recruiting"

    public static var saved: RecruitingDetails {
        get { UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(RecruitingDetails.self, from: $0) } ?? RecruitingDetails() }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: key) }
    }
}

#if os(iOS)
/// Renders a view to a one-page PDF or a picture, for sharing.
@MainActor
enum ReportRenderer {
    static let pageSize = CGSize(width: 595, height: 842)

    static func pdf<Content: View>(_ content: Content, fileName: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appending(path: fileName)
        let renderer = ImageRenderer(content: content.frame(width: pageSize.width, height: pageSize.height))
        var written = false
        renderer.render { _, draw in
            var box = CGRect(origin: .zero, size: pageSize)
            guard let consumer = CGDataConsumer(url: url as CFURL),
                  let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { return }
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
            context.closePDF()
            written = true
        }
        return written ? url : nil
    }

    static func image<Content: View>(_ content: Content) -> Image? {
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}

/// The printable report: for a coach, a parent, or a recruiter (with the
/// recruiting details).
struct ReportPage: View {
    let report: AthleteReport
    var recruiting: RecruitingDetails? = nil

    private var period: String {
        "\(report.from.formatted(date: .abbreviated, time: .omitted)) – \(report.to.formatted(date: .abbreviated, time: .omitted))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(recruiting == nil ? "Training report" : "Athlete profile").font(.system(size: 26, weight: .bold))
                Text([report.name, report.sport, report.position, "Age \(report.age)"].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 13))
                Text(period).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if let recruiting {
                let parts: [String] = [
                    recruiting.graduationYear.map { "Class of \($0)" },
                    recruiting.heightCm.map { Measure.height(cm: $0) },
                    recruiting.school,
                ].compactMap { $0 }
                if !parts.isEmpty { Text(parts.joined(separator: " · ")).font(.system(size: 13, weight: .semibold)) }
                if let highlights = recruiting.highlights, !highlights.isEmpty {
                    Text("Highlights: \(highlights)").font(.system(size: 11))
                }
            }
            Divider()
            grid([("Workouts", "\(report.workouts)"), ("Minutes", "\(report.minutes)"), ("Team practices", "\(report.practices)"),
                  ("Check-ins", "\(report.checkIns)"), ("Longest streak", "\(report.longestStreak) days"),
                  ("Average sleep", report.averageSleep.map { String(format: "%.1f h", $0) } ?? "—")])
            if !report.tests.isEmpty {
                Text("Tests").font(.system(size: 15, weight: .semibold))
                ForEach(report.tests) { line in
                    HStack {
                        Text(line.name).font(.system(size: 12))
                        Spacer()
                        Text(line.best).font(.system(size: 12, weight: .semibold))
                        if let change = line.change { Text("(\(change))").font(.system(size: 11)).foregroundStyle(.secondary) }
                    }
                }
            }
            Spacer()
            Text("Made with AthleteOS. Self-reported training data; tests done by the athlete.")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .padding(40)
        .foregroundStyle(.black)
        .background(.white)
    }

    /// A plain Grid (lazy stacks don't render into a PDF).
    private func grid(_ items: [(String, String)]) -> some View {
        let rows = stride(from: 0, to: items.count, by: 3).map { Array(items[$0..<min($0 + 3, items.count)]) }
        return Grid(alignment: .leading, horizontalSpacing: 40, verticalSpacing: 12) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.1).font(.system(size: 18, weight: .bold))
                            Text(item.0).font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

/// The season in one shareable picture ("Wrapped" for athletes).
struct SeasonCard: View {
    let report: AthleteReport

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("MY SEASON").font(.system(size: 14, weight: .heavy)).tracking(2).foregroundStyle(.white.opacity(0.6))
            Text(report.sport).font(.system(size: 40, weight: .bold))
            big("\(report.workouts)", "workouts")
            big("\(report.minutes)", "minutes of training")
            big("\(report.longestStreak)", "days in a row, my longest streak")
            if let test = report.tests.first(where: { $0.change != nil }) {
                big(test.change ?? "", test.name.lowercased())
            }
            if let top = report.topExercise {
                Text("Most done: \(top)").font(.system(size: 17, weight: .semibold))
            }
            Spacer()
            Text("AthleteOS").font(.system(size: 15, weight: .bold)).foregroundStyle(Color(hex: "#E5383B"))
        }
        .padding(32)
        .frame(width: 360, height: 640, alignment: .topLeading)
        .foregroundStyle(.white)
        .background(.black)
    }

    private func big(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.system(size: 44, weight: .heavy))
            Text(label).font(.system(size: 15)).foregroundStyle(.white.opacity(0.7))
        }
    }
}
#endif

#if os(iOS)
/// Me → Reports: the season card to share, a PDF for a coach or parent,
/// and (Pro) a recruiting profile.
struct ReportsSheet: View {
    let athlete: Athlete
    let sessions: [Session]
    let catalogue: Catalogue

    @Environment(\.dismiss) private var dismiss
    @State private var details = RecruitingDetails.saved
    @State private var showingPaywall = false
    @State private var editingProfile = false

    private var from: Date {
        if let sport = athlete.activeSport, sport.seasonStart < .now { return sport.seasonStart }
        return Calendar.current.date(byAdding: .month, value: -3, to: .now) ?? .now
    }

    private var report: AthleteReport {
        let sport = athlete.activeSport
        let info = sport.flatMap { allSportsBySlug[$0.sportSlug] }
        let position = sport?.positionSlug.flatMap { slug in info?.positions.first { $0.slug == slug }?.name }
        let names = sessions.flatMap { $0.sets.map(\.itemSlug) }.map { catalogue.item($0)?.name ?? displayName(forSlug: $0) }
        return AthleteReport.make(AthleteReport.Input(
            name: athlete.displayName, sport: info?.name ?? "My sport", position: position,
            age: PlanGenerator.ageInYears(birthDate: athlete.birthDate, now: .now),
            sessionDates: sessions.map(\.startedAt), sessionMinutes: sessions.map(\.minutes), exerciseNames: names,
            practiceDays: PracticeLogStore.logs.map(\.day), checkInDates: athlete.checkIns.map(\.date),
            sleepHours: athlete.checkIns.filter { $0.date >= from }.compactMap(\.sleepHours),
            lessons: CampusProgress.newLessonDates().filter { $0 >= from }.count,
            results: BenchmarkStore.results, tests: BenchmarkCatalog.tests(for: sport?.sportSlug)
        ), from: from, to: .now)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle("Reports", subtitle: "Your season, to share or print.")
                    let current = report
                    SeasonCard(report: current)
                        .scaleEffect(0.8)
                        .frame(width: 288, height: 512)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .frame(maxWidth: .infinity)
                    if let image = ReportRenderer.image(SeasonCard(report: current)) {
                        ShareLink(item: image, preview: SharePreview("My season", image: image)) {
                            Label("Share my season", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.primary)
                    }
                    if let pdf = ReportRenderer.pdf(ReportPage(report: current), fileName: "AthleteOS report.pdf") {
                        ShareLink(item: pdf) {
                            Label("PDF for a coach or parent", systemImage: "doc.richtext")
                        }
                        .buttonStyle(.secondary)
                    }

                    SectionHeader("Recruiting profile", subtitle: "Tests, training and your details, for college coaches.")
                    if ProAccess.isPro {
                        recruitingCard(current)
                    } else {
                        Button("See what Pro adds") { showingPaywall = true }
                            .buttonStyle(.secondary)
                    }
                }
                .padding(20)
            }
            .appScreen()
            .toolbar {
                CloseToolbarItem { dismiss() }
            }
            .proFeature(isPresented: $showingPaywall, athlete: athlete, feature: .dataExport)
        }
    }

    @ViewBuilder
    private func recruitingCard(_ current: AthleteReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Stepper(value: Binding(get: { details.graduationYear ?? Calendar.current.component(.year, from: .now) + 1 },
                                   set: { details.graduationYear = $0 }), in: 2024...2040) {
                Text("Class of \(details.graduationYear.map(String.init) ?? "—")")
            }
            Stepper(value: Binding(get: { details.heightCm ?? 170 }, set: { details.heightCm = $0 }), in: 120...230) {
                Text("Height: \(details.heightCm.map { Measure.height(cm: $0) } ?? "—")")
            }
            TextField("School (optional)", text: Binding(get: { details.school ?? "" }, set: { details.school = $0.isEmpty ? nil : $0 }))
            TextField("Highlight video link (optional)", text: Binding(get: { details.highlights ?? "" }, set: { details.highlights = $0.isEmpty ? nil : $0 }))
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
            Text("Only in the file you share. Don't add a phone number or address.")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
            if let pdf = ReportRenderer.pdf(ReportPage(report: current, recruiting: details), fileName: "AthleteOS profile.pdf") {
                ShareLink(item: pdf) { Label("Share profile (PDF)", systemImage: "square.and.arrow.up") }
                    .buttonStyle(.primary)
            }
        }
        .cardStyle()
        .onChange(of: details) { _, new in RecruitingDetails.saved = new }
    }
}
#endif
