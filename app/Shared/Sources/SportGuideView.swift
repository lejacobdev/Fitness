import SwiftUI

/// "Know your sport": the sport's guide as one page — what wins, where the
/// athlete is in the season, what the sport asks of the body, what the best
/// do, their position, the gym work and injury prevention that matter,
/// mindset and fuel, the studies behind it, and a quiz that earns Campus XP.
struct SportGuideView: View {
    let athlete: Athlete
    @Environment(\.dismiss) private var dismiss
    @State private var slug: String
    @State private var catalogue = Catalogue()
    @State private var detailItem: CatalogueItem?
    @State private var quizzing: SportGuide?
    @State private var newBadges: BadgeCelebration?
    @State private var passed = SportGuideProgress.passed()
    @State private var showingOtherPositions = false

    init(athlete: Athlete, sportSlug: String? = nil) {
        self.athlete = athlete
        _slug = State(initialValue: sportSlug ?? Self.guideSlugs(athlete).first ?? "")
    }

    /// The athlete's sports that have a guide, the active one first.
    static func guideSlugs(_ athlete: Athlete) -> [String] {
        var seen = Set<String>()
        return athlete.sortedSports.map(\.sportSlug).filter { sportGuidesBySlug[$0] != nil && seen.insert($0).inserted }
    }

    private var guide: SportGuide? { sportGuidesBySlug[slug] }
    private var sport: SportInfo? { allSportsBySlug[slug] }
    private var athleteSport: AthleteSport? { athlete.sports.first { $0.sportSlug == slug } }
    private var sportName: String { sport?.name ?? displayName(forSlug: slug) }

    private var phase: SeasonPhase? {
        athleteSport.map { PhaseCalculator.phase(today: .now, seasonStart: $0.seasonStart, seasonEnd: $0.seasonEnd) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let guide {
                    VStack(alignment: .leading, spacing: 28) {
                        header(guide)
                        if Self.guideSlugs(athlete).count > 1 { sportPicker }
                        if let phase { nowCard(guide, phase: phase) }
                        demands(guide)
                        succeed(guide)
                        positions(guide)
                        season(guide)
                        gym(guide)
                        injuries(guide)
                        mindsetAndFuel(guide)
                        quizCard(guide)
                        sources(guide)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .padding(.bottom, 30)
                    .containerRelativeFrame(.horizontal)
                } else {
                    ContentUnavailableView("No guide for this sport yet", systemImage: "book.closed",
                                           description: Text("Guides cover the 29 main sports. Switch to one of them in Me → Sports to read its guide."))
                        .padding(.top, 60)
                }
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .appScreen()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { catalogue = CatalogueLoader.load(from: AppConfig.packsDirectory()) }
            .sheet(item: $detailItem) { item in
                NavigationStack { ItemDetailView(item: item) }
            }
            .fullScreenCover(item: $quizzing) { guide in
                CampusLessonPlayer(
                    lesson: CampusLesson(id: "guide-\(guide.slug)", title: "Know your sport", minutes: 3, sections: [], takeaways: []),
                    customSteps: guide.quizSteps
                ) { earned in
                    SportGuideProgress.markPassed(guide.slug)
                    passed = SportGuideProgress.passed()
                    let badges = CampusProgress.earn(earned, lesson: true)
                    if !badges.isEmpty { newBadges = BadgeCelebration(badges: badges) }
                }
            }
            .sheet(item: $newBadges) { celebration in
                BadgeCelebrationView(badges: celebration.badges)
                    .presentationDetents([.medium])
            }
        }
    }

    // MARK: Sections

    private func header(_ guide: SportGuide) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Know your sport")
                .font(.subheadline.weight(.heavy))
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.brand)
            Text(sportName)
                .font(.system(size: 38, weight: .heavy))
                .foregroundStyle(AppTheme.ink)
            Text(guide.headline)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var sportPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Self.guideSlugs(athlete), id: \.self) { s in
                    Button { slug = s } label: {
                        Text(allSportsBySlug[s]?.name ?? displayName(forSlug: s))
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 40)
                            .foregroundStyle(s == slug ? AppTheme.onAccent : AppTheme.ink)
                            .background(s == slug ? AppTheme.accent : AppTheme.fill, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    /// Where the athlete is in their season, and what that means right now.
    private func nowCard(_ guide: SportGuide, phase: SeasonPhase) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Right now: \(AthleteStats.phaseLabel(phase))", systemImage: "calendar")
                .font(.headline)
                .foregroundStyle(AppTheme.onAccent)
            Text(guide.seasonAdvice(for: phase))
                .font(.body)
                .foregroundStyle(AppTheme.onAccent)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
    }

    private func demands(_ guide: SportGuide) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("What the sport asks", subtitle: "What your body has to do in a game or race.")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(guide.demands, id: \.self) { d in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(d.label)
                            .font(.caption.weight(.bold))
                            .textCase(.uppercase)
                            .foregroundStyle(AppTheme.secondaryText)
                        Text(d.value)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
                    .cardStyle(padding: 14)
                }
            }
        }
    }

    private func succeed(_ guide: SportGuide) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("What the best do", subtitle: "The habits that separate good from great.")
            ForEach(Array(guide.succeed.enumerated()), id: \.offset) { i, tip in
                HStack(alignment: .top, spacing: 14) {
                    Text("\(i + 1)")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(AppTheme.onAccent)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.accent, in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tip.title).font(.headline).foregroundStyle(AppTheme.ink)
                        Text(tip.body)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func positions(_ guide: SportGuide) -> some View {
        let all = sport?.positions ?? []
        let mine = athleteSport?.positionSlug.flatMap { p in all.first { $0.slug == p } }
        if !all.isEmpty, !guide.positions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(mine == nil ? "By position" : "Your position", subtitle: "What matters most in each role.")
                if let mine, let tip = guide.positions[mine.slug] {
                    positionRow(mine.name, tip, highlighted: true)
                }
                let others = all.filter { $0.slug != mine?.slug && guide.positions[$0.slug] != nil }
                if mine == nil || showingOtherPositions {
                    ForEach(others, id: \.slug) { p in positionRow(p.name, guide.positions[p.slug] ?? "", highlighted: false) }
                } else if !others.isEmpty {
                    Button("Show the other positions") { showingOtherPositions = true }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
    }

    private func positionRow(_ name: String, _ tip: String, highlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name).font(.headline).foregroundStyle(AppTheme.ink)
            Text(tip)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 16)
        .overlay {
            if highlighted {
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.accent, lineWidth: 2)
            }
        }
    }

    private func season(_ guide: SportGuide) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Through the year", subtitle: "Your plan changes with the season — this is why.")
            VStack(spacing: 0) {
                seasonRow("Off-season", guide.season.off, current: phase == .offSeason || phase == .postSeason)
                Divider()
                seasonRow("Pre-season", guide.season.pre, current: phase == .preSeason)
                Divider()
                seasonRow("In-season", guide.season.inSeason, current: phase == .inSeason)
            }
            .cardStyle(padding: 16)
        }
    }

    private func seasonRow(_ title: String, _ body: String, current: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(title).font(.headline).foregroundStyle(AppTheme.ink)
                if current { Tag("Now", color: AppTheme.brand) }
            }
            Text(body)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }

    private func gym(_ guide: SportGuide) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("In the gym", subtitle: "What to build. Your plan already includes these — tap one to see how it's done.")
            VStack(alignment: .leading, spacing: 8) {
                ForEach(guide.gym.focus, id: \.self) { f in
                    Label(f, systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.ink)
                }
            }
            exerciseChips(guide.gym.exercises)
        }
    }

    private func injuries(_ guide: SportGuide) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Stay healthy", subtitle: "The injuries this sport sees most, and what prevents them. Pain that doesn't go away: tell your coach or athletic trainer.")
            ForEach(guide.injuries, id: \.self) { injury in
                VStack(alignment: .leading, spacing: 10) {
                    Label(injury.area, systemImage: "cross.case.fill")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Text(injury.body)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    if !injury.exercises.isEmpty { exerciseChips(injury.exercises) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle(padding: 16)
            }
        }
    }

    /// Exercises by name; the ones in the downloaded library open their page.
    private func exerciseChips(_ slugs: [String]) -> some View {
        WrapLayout(spacing: 8) {
            ForEach(slugs, id: \.self) { s in
                let item = catalogue.item(s)
                Button { detailItem = item } label: {
                    HStack(spacing: 6) {
                        Text(item?.name ?? displayName(forSlug: s)).lineLimit(1)
                        if item != nil { Image(systemName: "chevron.right").font(.caption2.weight(.bold)) }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 38)
                    .background(AppTheme.fill, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(item == nil)
            }
        }
    }

    private func mindsetAndFuel(_ guide: SportGuide) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Mind and fuel", subtitle: "The parts of performance you can't see.")
            VStack(alignment: .leading, spacing: 10) {
                Label("Mindset", systemImage: "brain.head.profile").font(.headline).foregroundStyle(AppTheme.ink)
                ForEach(guide.mindset, id: \.self) { m in
                    Text("• \(m)")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(padding: 16)
            VStack(alignment: .leading, spacing: 10) {
                Label("Fuel", systemImage: "fork.knife").font(.headline).foregroundStyle(AppTheme.ink)
                Text(guide.fuel)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(padding: 16)
        }
    }

    private func quizCard(_ guide: SportGuide) -> some View {
        let done = passed.contains(guide.slug)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: done ? "checkmark.seal.fill" : "questionmark.bubble.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(done ? Duo.gold : AppTheme.brand, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(done ? "Quiz passed" : "Test yourself").font(.title3.weight(.heavy)).foregroundStyle(AppTheme.ink)
                    Text(done ? "Take it again any time for more Campus XP." : "\(guide.quiz.count) questions about \(sportName) — earns Campus XP.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button(done ? "Take the quiz again" : "Start the quiz") { quizzing = guide }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous).stroke(AppTheme.hairline, lineWidth: 2))
    }

    private func sources(_ guide: SportGuide) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("The science", subtitle: "Everything above comes from these studies and guidelines.")
            ForEach(guide.sources, id: \.self) { source in
                VStack(alignment: .leading, spacing: 4) {
                    if let url = URL(string: source.url) {
                        Link(destination: url) {
                            Text(source.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.ink)
                                .underline()
                                .multilineTextAlignment(.leading)
                        }
                    }
                    Text(source.detail)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("General education, not medical advice. For pain, illness or injury, see a doctor or athletic trainer.")
                .font(.footnote)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }
}

/// The entry to a sport guide (Campus and Workout): a big tappable card.
struct SportGuideCard: View {
    let athlete: Athlete
    let action: () -> Void

    private var slug: String? { SportGuideView.guideSlugs(athlete).first }

    var body: some View {
        if let slug, let guide = sportGuidesBySlug[slug] {
            let passed = SportGuideProgress.passed().contains(slug)
            Button(action: action) {
                HStack(spacing: 14) {
                    Image(systemName: "book.closed.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.onAccent)
                        .frame(width: 48, height: 48)
                        .background(AppTheme.accent, in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Know your sport: \(allSportsBySlug[slug]?.name ?? displayName(forSlug: slug))")
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(passed ? "Quiz passed · what wins, the season, staying healthy" : "What wins, the season, staying healthy — and a quiz (\(guide.quiz.count) questions)")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right").foregroundStyle(AppTheme.secondaryText)
                }
                .cardStyle(padding: 14)
            }
            .buttonStyle(.plain)
        }
    }
}
