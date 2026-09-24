import SwiftData
import SwiftUI

extension QualityGroup {
    var color: Color {
        switch self {
        case .speed: AppTheme.orange
        case .power: AppTheme.brand
        case .strength: AppTheme.blue
        case .endurance: AppTheme.green
        case .control: AppTheme.purple
        }
    }

    var systemImage: String {
        switch self {
        case .speed: "hare.fill"
        case .power: "bolt.fill"
        case .strength: "dumbbell.fill"
        case .endurance: "heart.fill"
        case .control: "figure.mind.and.body"
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}

struct RankedQuality: Identifiable {
    let quality: QualityInfo
    let weight: Double
    var id: String { quality.id }
}

extension SportSkill {
    /// The skill's qualities, strongest first.
    var rankedQualities: [RankedQuality] {
        qualityWeights
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .compactMap { entry in qualitiesBySlug[entry.key].map { RankedQuality(quality: $0, weight: entry.value) } }
    }
}

enum ImproveRoute: Hashable {
    case setup(skillSlug: String)
    case block(skillSlug: String, gameDate: Date, seed: String, isSaved: Bool)
}

/// §8's skill menu — "the screen worth the most care." Three taps, no
/// typing: a skill, a game date, a dated plan that explains itself.
struct ImproveView: View {
    let athlete: Athlete
    let apiClient: APIClient
    let onPlanInputsChanged: () -> Void

    enum Mode: String, CaseIterable {
        case skill = "Get better at a skill"
        case muscles = "Train a muscle group"
    }

    @Query(sort: \SkillBlock.generatedAt, order: .reverse) private var allSkillBlocks: [SkillBlock]
    @State private var path: [ImproveRoute] = []
    @State private var searchText = ""
    @State private var mode: Mode = .skill

    private var sportSlug: String? { athlete.activeSport?.sportSlug }
    private var sportInfo: SportInfo? { sportSlug.flatMap { allSportsBySlug[$0] } }

    private var skills: [SportSkill] {
        let all = sportInfo?.skills ?? []
        return FuzzySearch.rank(all, query: searchText, fields: CatalogueSearch.fields)
    }

    private var savedBlocks: [SkillBlock] {
        allSkillBlocks.filter { $0.athlete?.id == athlete.id && $0.sportSlug == sportSlug }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle("Improve", subtitle: "Extra training for the one thing you want to get better at.")
                    HStack(spacing: 8) {
                        Text("Training for")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                        SportSwitcher(athlete: athlete, onChanged: onPlanInputsChanged)
                    }
                    if !savedBlocks.isEmpty {
                        savedSection
                    }
                    SectionHeader("What do you want to improve?", subtitle: "Choose one.")
                    modePicker
                    if mode == .skill {
                        howItWorks
                        searchField
                        skillGrid
                    } else {
                        TipCard(id: "muscles", icon: "figure.stand", title: "Build a workout by muscle",
                                message: "Tap a quick pick or the body areas you want to train, choose how long you have, then press Start workout.")
                        MuscleBuilderView(athlete: athlete, apiClient: apiClient)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .appScreen()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ImproveRoute.self) { route in
                switch route {
                case .setup(let skillSlug):
                    if let skill = sportInfo?.skills.first(where: { $0.slug == skillSlug }) {
                        SkillSetupView(athlete: athlete, skill: skill) { gameDate in
                            let seed = "\(athlete.id)-\(skill.slug)-\(Int(gameDate.timeIntervalSince1970))"
                            path.append(.block(skillSlug: skill.slug, gameDate: gameDate, seed: seed, isSaved: false))
                        }
                    }
                case .block(let skillSlug, let gameDate, let seed, let isSaved):
                    if let skill = sportInfo?.skills.first(where: { $0.slug == skillSlug }) {
                        SkillBlockView(athlete: athlete, skill: skill, gameDate: gameDate, seed: seed, alreadySaved: isSaved) {
                            path.removeAll()
                        }
                    }
                }
            }
        }
    }

    /// Two big, self-explaining choices instead of a small toggle.
    private var modePicker: some View {
        HStack(spacing: 12) {
            ForEach(Mode.allCases, id: \.self) { value in
                let selected = mode == value
                Button {
                    withAnimation(.snappy) { mode = value }
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: value == .skill ? "target" : "figure.strengthtraining.traditional")
                            .font(.system(size: 20, weight: .semibold))
                        Text(value == .skill ? "A skill" : "Muscles")
                            .font(.headline)
                        Text(value == .skill ? "Like shooting or first-step speed. You get a day-by-day plan up to your next game." : "Pick body areas. You get one workout to do right now.")
                            .font(.caption)
                            .foregroundStyle(selected ? AppTheme.inkInverse.opacity(0.8) : AppTheme.secondaryText)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(selected ? AppTheme.inkInverse : AppTheme.ink)
                    .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
                    .padding(16)
                    .background(selected ? AppTheme.ink : AppTheme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(selected ? 0.15 : 0.05), radius: 8, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(value == .skill ? "Improve a skill" : "Train muscles")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var howItWorks: some View {
        HStack(spacing: 0) {
            step(1, "Pick a skill", "target")
            connector
            step(2, "Set your game", "calendar")
            connector
            step(3, "Get the plan", "list.bullet.clipboard")
        }
        .cardStyle(padding: 16)
    }

    private func step(_ number: Int, _ title: String, _ icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.inkInverse)
                .frame(width: 42, height: 42)
                .background(AppTheme.ink, in: Circle())
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number): \(title)")
    }

    private var connector: some View {
        Rectangle()
            .fill(AppTheme.hairline)
            .frame(width: 18, height: 2)
            .padding(.bottom, 22)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.secondaryText)
            TextField("Search \(sportInfo?.name.lowercased() ?? "") skills", text: $searchText)
                .foregroundStyle(AppTheme.ink)
        }
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    @ViewBuilder
    private var skillGrid: some View {
        if skills.isEmpty {
            Text(sportInfo == nil ? "Pick a sport first — the skill menu works from your sport." : "No skill matches \"\(searchText)\".")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .frame(maxWidth: .infinity)
                .cardStyle()
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(skills, id: \.slug) { skill in
                    NavigationLink(value: ImproveRoute.setup(skillSlug: skill.slug)) {
                        skillCard(skill)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func skillCard(_ skill: SportSkill) -> some View {
        let top = skill.rankedQualities.prefix(2)
        let group = top.first?.quality.group ?? .power
        return VStack(alignment: .leading, spacing: 12) {
            Image(systemName: group.systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(group.color)
                .frame(width: 40, height: 40)
                .background(group.color.opacity(0.13), in: Circle())
            Text(skill.name)
                .font(.headline)
                .foregroundStyle(AppTheme.ink)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Needs " + top.map { $0.quality.shortName.lowercased() }.joined(separator: " and "))
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .cardStyle(padding: 16)
    }

    private var savedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Your skill plans", subtitle: "Today's drills from these also show on your Today screen.")
            ForEach(savedBlocks) { saved in
                NavigationLink(value: ImproveRoute.block(skillSlug: saved.skillSlug, gameDate: saved.targetDate, seed: saved.seed, isSaved: true)) {
                    HStack(spacing: 14) {
                        Image(systemName: "bookmark.fill")
                            .foregroundStyle(AppTheme.ink)
                            .frame(width: 48, height: 48)
                            .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(sportInfo?.skills.first { $0.slug == saved.skillSlug }?.name ?? displayName(forSlug: saved.skillSlug))
                                .font(.headline)
                                .foregroundStyle(AppTheme.ink)
                            Text("Game on \(saved.targetDate.formatted(.dateTime.weekday(.abbreviated).month().day()))")
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .cardStyle(padding: 12)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Step two: "My next game is…" plus what the skill actually depends on.
struct SkillSetupView: View {
    let athlete: Athlete
    let skill: SportSkill
    let onBuild: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var gameDate: Date
    @State private var catalogue = Catalogue()
    @State private var detailItem: CatalogueItem?

    init(athlete: Athlete, skill: SportSkill, onBuild: @escaping (Date) -> Void) {
        self.athlete = athlete
        self.skill = skill
        self.onBuild = onBuild
        let nextGame = AthleteStats.upcomingCompetitions(athlete).first?.date
        _gameDate = State(initialValue: nextGame ?? Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now)
    }

    private var upcomingGames: [Competition] {
        Array(AthleteStats.upcomingCompetitions(athlete).prefix(3))
    }

    /// Drills written for exactly this skill, then the library items that
    /// best match its qualities — "what are the best exercises for this?"
    private var bestDrills: [CatalogueItem] {
        let sport = athlete.activeSport?.sportSlug
        let tagged = catalogue.itemsBySlug.values
            .filter { $0.baseSlug == nil && $0.itemSportSlug == sport && ($0.skills ?? []).contains(skill.slug) }
            .sorted { $0.name < $1.name }
        let weights = skill.qualityWeights
        func score(_ item: CatalogueItem) -> Double {
            item.qualities.reduce(0) { $0 + $1.value * (weights[$1.key] ?? 0) }
        }
        let matched = catalogue.itemsBySlug.values
            .filter { $0.baseSlug == nil && !tagged.contains($0) && ($0.itemSportSlug == nil || $0.itemSportSlug == sport) }
            .sorted { score($0) != score($1) ? score($0) > score($1) : $0.slug < $1.slug }
        return Array((tagged + matched).prefix(8))
    }

    var body: some View {
        StepScaffold(
            progress: 0.66, title: skill.name, subtitle: "When is your next game?",
            buttonTitle: "Build my plan", onBack: { dismiss() }, onContinue: { onBuild(gameDate) }
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(upcomingGames) { game in
                            quickChip("Game · \(game.date.formatted(.dateTime.month(.abbreviated).day()))", date: game.date)
                        }
                        quickChip("In 3 days", date: Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now)
                        quickChip("In 1 week", date: Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now)
                        quickChip("In 2 weeks", date: Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now)
                    }
                }
                DatePicker("Game date", selection: $gameDate, in: Calendar.current.startOfDay(for: .now)..., displayedComponents: .date)
                    .labelsHidden()
                    .calendarDatePickerStyle()
                    .tint(AppTheme.ink)
                    .cardStyle(padding: 12)
            }

            VStack(alignment: .leading, spacing: 14) {
                Text("What \(skill.name.lowercased()) depends on")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                ForEach(skill.rankedQualities.prefix(5)) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: entry.quality.group.systemImage)
                                .font(.caption)
                                .foregroundStyle(entry.quality.group.color)
                            Text(entry.quality.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.ink)
                            Spacer()
                        }
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(AppTheme.fill)
                                Capsule()
                                    .fill(entry.quality.group.color)
                                    .frame(width: proxy.size.width * entry.weight)
                            }
                        }
                        .frame(height: 6)
                        Text(entry.quality.info)
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
            }
            .cardStyle()

            if !bestDrills.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Best exercises and drills for it")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    ForEach(bestDrills) { item in
                        Button {
                            detailItem = item
                        } label: {
                            HStack(spacing: 12) {
                                ItemThumbnail(item: item, size: 48)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.name)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(AppTheme.ink)
                                        .multilineTextAlignment(.leading)
                                    Text(item.kind == "drill" ? "\(skill.name) drill · \(DoseFormatter.text(item.defaultDose))" : "Builds what \(skill.name.lowercased()) needs · \(DoseFormatter.text(item.defaultDose))")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .cardStyle()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { catalogue = CatalogueLoader.load(from: AppConfig.packsDirectory()) }
        .sheet(item: $detailItem) { item in
            NavigationStack { ItemDetailView(item: item) }
        }
    }

    private func quickChip(_ title: String, date: Date) -> some View {
        Button {
            gameDate = date
        } label: {
            Chip(title, isSelected: Calendar.current.isDate(date, inSameDayAs: gameDate))
        }
        .buttonStyle(.plain)
    }
}

/// Step three: the dated block, day by day, each item explaining itself.
struct SkillBlockView: View {
    let athlete: Athlete
    let skill: SportSkill
    let gameDate: Date
    let seed: String
    let alreadySaved: Bool
    let onFinished: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var block: GeneratedSkillBlock?
    @State private var catalogue = Catalogue()
    @State private var isSaved = false
    @State private var detailItem: CatalogueItem?
    @State private var showingPaywall = false

    private var saveHint: String {
        let remaining = ProGate.remainingSkillBlocks(isPro: ProAccess.isPro, savedBlockDates: athlete.skillBlocks.map(\.generatedAt))
        let base = "Saving puts each day's drills on your Today screen."
        guard let remaining else { return base }
        return base + " \(remaining) of \(ProLimits.freeSkillBlocksPerMonth) free plans left this month."
    }

    private var trainingDays: Int {
        block?.days.filter { !$0.items.isEmpty }.count ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    CircleIconButton(systemImage: "chevron.left", accessibilityLabel: "Back") { dismiss() }
                    Spacer()
                }
                if let block {
                    hero(block)
                    expectationCard(block)
                    ForEach(Array(block.days.enumerated()), id: \.offset) { index, day in
                        dayCard(day, dayNumber: index + 1, isLast: index == block.days.count - 1)
                    }
                    if isSaved {
                        Label("Saved — today's drills show on your Today screen", systemImage: "checkmark.circle.fill")
                            .multilineTextAlignment(.center)
                            .font(.headline)
                            .foregroundStyle(AppTheme.green)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        Button("Done", action: onFinished)
                            .buttonStyle(.secondary)
                    } else {
                        VStack(spacing: 8) {
                            Button("Save this plan", action: save)
                                .buttonStyle(.primary)
                            Text(saveHint)
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        .appScreen()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $detailItem) { item in
            NavigationStack { ItemDetailView(item: item) }
        }
        .skillPlanPaywall(isPresented: $showingPaywall, athlete: athlete)
        .task {
            isSaved = alreadySaved
            catalogue = CatalogueLoader.load(from: AppConfig.packsDirectory())
            guard let sportSlug = athlete.activeSport?.sportSlug else { return }
            block = SkillMenuEngine.generate(SkillMenuInput(
                sportSlug: sportSlug, skillSlug: skill.slug, skillName: skill.name,
                qualityWeights: skill.qualityWeights,
                // A saved plan keeps the dates it was made with, so its days
                // don't shift each time it's opened.
                today: athlete.skillBlocks.first { $0.seed == seed }?.generatedAt ?? .now, gameDate: gameDate,
                birthDate: athlete.birthDate, trainsUnderCoach: athlete.trainsUnderCoach,
                equipmentAvailable: Set(athlete.equipmentAvailable), catalogue: catalogue, seed: seed
            ))
        }
    }

    private func hero(_ block: GeneratedSkillBlock) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(skill.name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                Text("Game \(gameDate.formatted(.dateTime.weekday(.wide).month().day()))")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                HStack(spacing: 6) {
                    ForEach(skill.rankedQualities.prefix(2)) { entry in
                        Tag(entry.quality.shortName, color: entry.quality.group.color)
                    }
                }
            }
            Spacer(minLength: 0)
            RingView(progress: 1, color: AppTheme.ink, lineWidth: 9) {
                VStack(spacing: 0) {
                    Text("\(block.days.count)")
                        .font(.title2.bold())
                        .foregroundStyle(AppTheme.ink)
                    Text("days")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .frame(width: 92, height: 92)
        }
        .cardStyle(padding: 22)
    }

    private func expectationCard(_ block: GeneratedSkillBlock) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(AppTheme.amber)
            VStack(alignment: .leading, spacing: 4) {
                Text("What to expect")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.ink)
                Text(block.realisticExpectation)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
                Text("\(trainingDays) training days, the heavy work early, sharp and fresh for the game.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 16)
    }

    private func dayCard(_ day: GeneratedSession, dayNumber: Int, isLast: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Group {
                    if isLast {
                        Image(systemName: "flag.checkered")
                    } else {
                        Text("\(dayNumber)")
                    }
                }
                .font(.subheadline.bold())
                .foregroundStyle(isLast ? AppTheme.ink : AppTheme.inkInverse)
                .frame(width: 34, height: 34)
                .background(isLast ? AppTheme.fill : AppTheme.ink, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.date.formatted(.dateTime.weekday(.wide).month().day()))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                    Text(day.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                }
                Spacer(minLength: 0)
                if day.estimatedMinutes > 0 {
                    Text("\(day.estimatedMinutes) min")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppTheme.fill, in: Capsule())
                }
            }
            ForEach(day.items, id: \.order) { item in
                let catalogueItem = catalogue.item(item.itemSlug)
                Button {
                    detailItem = catalogueItem
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        ItemThumbnail(item: catalogueItem, size: 48)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(catalogueItem?.name ?? displayName(forSlug: item.itemSlug))
                                .font(.subheadline.bold())
                                .foregroundStyle(AppTheme.ink)
                                .multilineTextAlignment(.leading)
                            Text(DoseFormatter.text(item.dose))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.orange)
                            Text(item.rationale)
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)
                .disabled(catalogueItem == nil)
            }
            if !day.items.isEmpty {
                let isToday = Calendar.current.isDateInToday(day.date)
                StartWorkoutButton(isToday ? "Start today's drills" : "Do day \(dayNumber) now", session: day, prominent: isToday)
                    .padding(.top, 2)
            }
        }
        .cardStyle(padding: 16)
    }

    private func save() {
        guard let sportSlug = athlete.activeSport?.sportSlug else { return }
        #if os(iOS) && !APP_EXTENSION
        // §4: three saved skill plans a month on free, unlimited on Pro.
        guard ProGate.canSaveSkillBlock(isPro: ProStore.shared.isPro, savedBlockDates: athlete.skillBlocks.map(\.generatedAt)) else {
            showingPaywall = true
            return
        }
        #endif
        try? SkillBlockStore(modelContext: modelContext).save(
            athlete: athlete, sportSlug: sportSlug, skillSlug: skill.slug, targetDate: gameDate, seed: seed
        )
        isSaved = true
    }
}

extension View {
    /// The Pro paywall where StoreKit exists (the iOS app); a no-op in the
    /// widget and watch builds that also compile this file.
    @ViewBuilder
    func skillPlanPaywall(isPresented: Binding<Bool>, athlete: Athlete) -> some View {
        proPaywall(isPresented: isPresented, athlete: athlete, feature: .skillBlocks)
    }
}
