import SwiftData
import SwiftUI

/// §15 Tab 2: "The week, phase-labelled, with the competition marked. Tap any
/// day to see it... A prominent 'Add a game' button — never more than one
/// tap away."
struct PlanView: View {
    let athlete: Athlete
    let week: GeneratedWeek?
    let onPlanInputsChanged: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var selectedDate = Date.now
    @State private var catalogue = Catalogue()
    @State private var showingAddGame = false
    @State private var detailItem: CatalogueItem?
    @State private var gamePendingDelete: Competition?
    @State private var confirmingNewPlan = false
    @AppStorage(PlanVariant.key) private var planVariant = 0

    private var calendar: Calendar { .current }
    private var athleteSport: AthleteSport? { athlete.activeSport }

    private var weekDays: [Date] {
        guard let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private func session(on day: Date) -> GeneratedSession? {
        week?.sessions.first { calendar.isDate($0.date, inSameDayAs: day) }
    }

    private func game(on day: Date) -> Competition? {
        athlete.competitions.first { calendar.isDate($0.date, inSameDayAs: day) }
    }

    private var markedDays: Set<Date> {
        var days = Set((week?.sessions ?? []).map { calendar.startOfDay(for: $0.date) })
        days.formUnion(athlete.competitions.map { calendar.startOfDay(for: $0.date) })
        return days
    }

    private var seasonProgress: Double {
        guard let athleteSport else { return 0 }
        let total = athleteSport.seasonEnd.timeIntervalSince(athleteSport.seasonStart)
        guard total > 0 else { return 0 }
        return max(0, min(1, Date.now.timeIntervalSince(athleteSport.seasonStart) / total))
    }

    private var phaseExplanation: String {
        switch week?.phase {
        case .offSeason: "No games for a while, so this is when you get stronger and fitter. Workouts are the longest of the year."
        case .preSeason: "The season is coming. Workouts get shorter but faster and more sport-like, so you're sharp for game one."
        case .inSeason: "Games come first. Two short workouts a week keep you strong without leaving you tired for games."
        case .postSeason: "The season's over. Workouts are light so your body can recover before the next build."
        case nil: "Pick your sport and we'll plan your week."
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top) {
                        ScreenTitle("Plan", subtitle: "Your training week, built around your games.")
                        Spacer(minLength: 8)
                        Button { showingAddGame = true } label: {
                            Label("Add game", systemImage: "plus")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.onAccent)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(AppTheme.accent, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 6)
                    }
                    HStack(spacing: 8) {
                        Text("Training for")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                        SportSwitcher(athlete: athlete, onChanged: onPlanInputsChanged)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        WeekStrip(selection: $selectedDate, marked: markedDays, gameDays: Set(athlete.competitions.map { calendar.startOfDay(for: $0.date) }))
                        WeekStripLegend()
                    }
                    selectedDayDetail
                    weekOverview
                    SectionHeader("Your season", subtitle: "Your training changes as the season goes on.")
                    phaseCard
                    gamesSection
                    planOptions
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .appScreen()
            .toolbar(.hidden, for: .navigationBar)
            .task { catalogue = CatalogueLoader.load(from: AppConfig.packsDirectory()) }
            .sheet(isPresented: $showingAddGame) {
                AddGameSheet(athlete: athlete, onSaved: onPlanInputsChanged)
            }
            .sheet(item: $detailItem) { item in
                NavigationStack { ItemDetailView(item: item) }
            }
            .confirmationDialog(
                "Remove this game?", isPresented: Binding(
                    get: { gamePendingDelete != nil }, set: { if !$0 { gamePendingDelete = nil } }
                ), titleVisibility: .visible
            ) {
                Button("Remove game", role: .destructive) { deletePendingGame() }
                Button("Cancel", role: .cancel) { gamePendingDelete = nil }
            } message: {
                Text("Your week will rearrange around the games that are left.")
            }
        }
    }

    // MARK: - Phase

    private var phaseCard: some View {
        HStack(spacing: 16) {
            RingView(progress: seasonProgress, color: AppTheme.blue, lineWidth: 7) {
                Text("\(Int(seasonProgress * 100))%")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.ink)
            }
            .frame(width: 70, height: 70)
            .accessibilityLabel("\(Int(seasonProgress * 100)) percent of the season done")
            VStack(alignment: .leading, spacing: 4) {
                Text("Now: " + AthleteStats.phaseLabel(week?.phase))
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.ink)
                if let athleteSport {
                    Text("Season runs \(athleteSport.seasonStart.formatted(.dateTime.month(.abbreviated).day())) – \(athleteSport.seasonEnd.formatted(.dateTime.month(.abbreviated).day())) · \(Int(seasonProgress * 100))% done")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.blue)
                }
                Text(phaseExplanation)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Selected day

    @ViewBuilder
    private var selectedDayDetail: some View {
        if let game = game(on: selectedDate) {
            dayHeader("Game day", subtitle: "No workout — just warm up and play. The rest of the week was planned so you're fresh today.", icon: "sportscourt.fill", color: AppTheme.brand)
                .accessibilityHint(game.notes ?? "")
        } else if let session = session(on: selectedDate) {
            VStack(alignment: .leading, spacing: 12) {
                dayHeader(session.title, subtitle: "About \(session.estimatedMinutes) min · \(session.items.count) exercises, in this order", icon: "figure.strengthtraining.traditional", color: AppTheme.orange)
                ForEach(session.items, id: \.order) { item in
                    itemRow(item)
                }
                StartWorkoutButton(calendar.isDateInToday(selectedDate) ? "Start today's session" : "Do this session now", session: session)
                    .padding(.top, 4)
            }
        } else {
            dayHeader("Rest day", subtitle: "No workout planned. Resting is part of getting stronger — sleep well and eat well.", icon: "moon.zzz.fill", color: AppTheme.purple)
        }
    }

    private func dayHeader(_ title: String, subtitle: String, icon: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 48, height: 48)
                .background(color.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(selectedDate.formatted(.dateTime.weekday(.wide).month().day()))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .cardStyle(padding: 16)
    }

    private func itemRow(_ item: GeneratedPlannedItem) -> some View {
        let catalogueItem = catalogue.item(item.itemSlug)
        return Button {
            detailItem = catalogueItem
        } label: {
            HStack(alignment: .top, spacing: 14) {
                ItemThumbnail(item: catalogueItem, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(catalogueItem?.name ?? displayName(forSlug: item.itemSlug))
                        .font(.subheadline.bold())
                        .foregroundStyle(AppTheme.ink)
                        .multilineTextAlignment(.leading)
                    Text(DoseFormatter.text(item.dose))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.orange)
                    Text("Why: " + item.rationale)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .cardStyle(padding: 12)
        }
        .buttonStyle(.plain)
        .disabled(catalogueItem == nil)
    }

    // MARK: - Week overview

    private var weekOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("The whole week", subtitle: "Tap a day to see it above.")
            VStack(spacing: 0) {
                ForEach(Array(weekDays.enumerated()), id: \.offset) { index, day in
                    Button {
                        selectedDate = day
                    } label: {
                        overviewRow(day)
                    }
                    .buttonStyle(.plain)
                    if index < weekDays.count - 1 {
                        Divider().overlay(AppTheme.hairline)
                    }
                }
            }
            .cardStyle(padding: 16)
        }
    }

    private func overviewRow(_ day: Date) -> some View {
        let session = session(on: day)
        let game = game(on: day)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        return HStack(spacing: 12) {
            Text(day.formatted(.dateTime.weekday(.abbreviated)))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? AppTheme.ink : AppTheme.secondaryText)
                .frame(width: 40, alignment: .leading)
            Circle()
                .fill(game != nil ? AppTheme.brand : (session != nil ? AppTheme.orange : AppTheme.fill))
                .frame(width: 10, height: 10)
            Text(game != nil ? "Game" : (session?.title ?? "Rest"))
                .font(.subheadline.weight(isSelected ? .bold : .regular))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
            Spacer()
            if let session, game == nil {
                Text("about \(session.estimatedMinutes) min")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - Games

    @ViewBuilder
    private var gamesSection: some View {
        let upcoming = AthleteStats.upcomingCompetitions(athlete)
        if !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Upcoming games", subtitle: "Your workouts get lighter in the days before each one.")
                VStack(spacing: 0) {
                    ForEach(Array(upcoming.enumerated()), id: \.element.id) { index, game in
                        gameRow(game)
                        if index < upcoming.count - 1 {
                            Divider().overlay(AppTheme.hairline)
                        }
                    }
                }
                .cardStyle(padding: 16)
            }
        }
    }

    private func gameRow(_ game: Competition) -> some View {
        let days = AthleteStats.daysUntil(game.date)
        return HStack(spacing: 12) {
            Image(systemName: game.kind == .tournament ? "trophy.fill" : (game.kind == .meet ? "flag.checkered" : "sportscourt.fill"))
                .foregroundStyle(AppTheme.brand)
                .frame(width: 36, height: 36)
                .background(AppTheme.brand.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(game.date.formatted(.dateTime.weekday(.wide).month().day()))
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.ink)
                Text("\(game.kind.rawValue.capitalized) · \(game.isHome ? "Home" : "Away")\(game.notes.map { " · \($0)" } ?? "")")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            Text(days == 0 ? "Today" : (days == 1 ? "Tomorrow" : "in \(days) days"))
                .font(.caption.bold())
                .foregroundStyle(AppTheme.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppTheme.fill, in: Capsule())
            Button {
                gamePendingDelete = game
            } label: {
                Image(systemName: "trash")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove game")
        }
        .padding(.vertical, 8)
    }

    /// Delete this plan and get a different one, or go back to the first.
    private var planOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Don't like this plan?", subtitle: "Delete it and get a new one. Same rules for your sport and season, different exercises.")
            Button { confirmingNewPlan = true } label: {
                Label("Delete plan and build a new one", systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline)
                    .foregroundStyle(AppTheme.red)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(AppTheme.red.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
            if planVariant > 0 {
                Button {
                    PlanVariant.backToOriginal()
                    onPlanInputsChanged()
                } label: {
                    Label("Back to my first plan", systemImage: "arrow.uturn.backward")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(AppTheme.fill, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .confirmationDialog("Delete this plan?", isPresented: $confirmingNewPlan, titleVisibility: .visible) {
            Button("Delete and build a new one", role: .destructive) {
                PlanVariant.buildNew()
                onPlanInputsChanged()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your week gets new exercises. Workouts you already logged stay.")
        }
    }

    private func deletePendingGame() {
        guard let game = gamePendingDelete else { return }
        modelContext.delete(game)
        try? modelContext.save()
        gamePendingDelete = nil
        onPlanInputsChanged()
    }
}

/// §10: "Add a game → the week visibly rearranges." Date, type, home/away,
/// and an optional note — the full shape of §14's `Competition`.
struct AddGameSheet: View {
    let athlete: Athlete
    let onSaved: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var date = Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now
    @State private var kind: CompetitionKind = .game
    @State private var isHome = true
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ScreenTitle("Add a game", subtitle: "Your week rearranges around it — heavy work early, sharp and fresh on the day.")

                    DatePicker("Date", selection: $date, in: Calendar.current.startOfDay(for: .now)..., displayedComponents: .date)
                        .labelsHidden()
                        .calendarDatePickerStyle()
                        .tint(AppTheme.accent)
                        .cardStyle(padding: 12)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Type")
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                        HStack(spacing: 8) {
                            kindChip(.game, "Game")
                            kindChip(.tournament, "Tournament")
                            kindChip(.meet, "Meet")
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Where")
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                        HStack(spacing: 8) {
                            Button { isHome = true } label: { Chip("Home", isSelected: isHome) }
                                .buttonStyle(.plain)
                            Button { isHome = false } label: { Chip("Away", isSelected: !isHome) }
                                .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Note")
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                        TextField("Opponent, time… (optional)", text: $notes)
                            .padding(16)
                            .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))
                    }

                    Button("Save game", action: save)
                        .buttonStyle(.primary)
                }
                .padding(20)
            }
            .appScreen()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppTheme.ink)
                }
            }
        }
    }

    private func kindChip(_ value: CompetitionKind, _ title: String) -> some View {
        Button { kind = value } label: { Chip(title, isSelected: kind == value) }
            .buttonStyle(.plain)
    }

    private func save() {
        guard let sportSlug = athlete.activeSport?.sportSlug else { return }
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let competition = Competition(
            sportSlug: sportSlug, date: date, kind: kind, isHome: isHome,
            notes: trimmed.isEmpty ? nil : trimmed, athlete: athlete
        )
        modelContext.insert(competition)
        try? modelContext.save()
        onSaved()
        dismiss()
    }
}

extension View {
    /// A month-grid date picker on iPhone; watchOS has no graphical style, so
    /// it keeps the platform default there.
    @ViewBuilder
    func calendarDatePickerStyle() -> some View {
        #if os(iOS)
        datePickerStyle(.graphical)
        #else
        self
        #endif
    }
}
