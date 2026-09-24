import SwiftData
import SwiftUI

/// The sport switcher that heads Today, Plan and Improve: shows which sport
/// the app is set to and switches in one tap. Plan, skills, drills and
/// suggestions all follow the active sport; games from every sport still
/// count, so the week never loads you up before any game.
/// When a free athlete changed sport (device-local), for the monthly allowance.
@MainActor
enum SportSwitchLedger {
    private static let key = "freeSportSwitchDates"

    static var dates: [Date] {
        (UserDefaults.standard.array(forKey: key) as? [Double] ?? []).map { Date(timeIntervalSince1970: $0) }
    }

    static var remaining: Int? { ProGate.remainingSportSwitches(isPro: ProAccess.isPro, switchDates: dates) }

    /// False when a free athlete has used this month's changes.
    static var canSwitch: Bool { (remaining ?? 1) > 0 }

    static func record() {
        guard !ProAccess.isPro else { return }
        let recent = dates.filter { $0 > .now.addingTimeInterval(-40 * 86_400) }.map(\.timeIntervalSince1970)
        UserDefaults.standard.set(recent + [Date.now.timeIntervalSince1970], forKey: key)
    }

    /// "2 of 3 sport changes left this month" (free only).
    static var summary: String? {
        remaining.map { "\($0) of \(ProLimits.freeSportSwitchesPerMonth) sport changes left this month" }
    }
}

struct SportSwitcher: View {
    let athlete: Athlete
    let onChanged: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var showingAdd = false
    @State private var showingManage = false
    @State private var showingPaywall = false
    @State private var showingChange = false

    private var canAdd: Bool { ProGate.canAddSport(isPro: ProAccess.isPro, currentSportCount: athlete.sports.count) }

    private var activeName: String {
        athlete.activeSport.map { allSportsBySlug[$0.sportSlug]?.name ?? displayName(forSlug: $0.sportSlug) } ?? "Pick a sport"
    }

    var body: some View {
        Group {
            #if os(iOS)
            Menu {
                Section("Switch sport") {
                    ForEach(athlete.sortedSports) { sport in
                        Button {
                            switchTo(sport)
                        } label: {
                            if sport.id == athlete.activeSport?.id {
                                Label(name(sport), systemImage: "checkmark")
                            } else {
                                Label(name(sport), systemImage: SportIcon.name(for: sport.sportSlug))
                            }
                        }
                    }
                }
                if !ProAccess.isPro {
                    Button {
                        if SportSwitchLedger.canSwitch { showingChange = true } else { showingPaywall = true }
                    } label: {
                        Label("Change sport", systemImage: "arrow.left.arrow.right")
                        if let summary = SportSwitchLedger.summary { Text(summary) }
                    }
                }
                Button {
                    if canAdd { showingAdd = true } else { showingPaywall = true }
                } label: {
                    Label(canAdd ? "Add a sport" : "Add a sport (Pro)", systemImage: canAdd ? "plus" : "crown.fill")
                }
                Button { showingManage = true } label: { Label("Manage sports", systemImage: "slider.horizontal.3") }
            } label: {
                label
            }
            #else
            Button { showingManage = true } label: { label }
                .buttonStyle(.plain)
            #endif
        }
        .accessibilityLabel("Sport: \(activeName). Double tap to switch or add a sport.")
        .sheet(isPresented: $showingAdd) {
            AddSportSheet(athlete: athlete, onSaved: onChanged)
        }
        .sheet(isPresented: $showingChange) {
            AddSportSheet(athlete: athlete, replacing: true, onSaved: onChanged)
        }
        .sheet(isPresented: $showingManage) {
            SportsManagerSheet(athlete: athlete, onChanged: onChanged)
        }
        .proPaywall(isPresented: $showingPaywall, athlete: athlete, feature: .multipleSports)
    }

    private var label: some View {
        HStack(spacing: 6) {
            Image(systemName: athlete.activeSport.map { SportIcon.name(for: $0.sportSlug) } ?? "sportscourt.fill")
                .font(.footnote.weight(.semibold))
            Text(activeName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .foregroundStyle(AppTheme.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.card, in: Capsule())
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    private func name(_ sport: AthleteSport) -> String {
        allSportsBySlug[sport.sportSlug]?.name ?? displayName(forSlug: sport.sportSlug)
    }

    private func switchTo(_ sport: AthleteSport) {
        guard sport.id != athlete.activeSport?.id else { return }
        guard SportSwitchLedger.canSwitch else { showingPaywall = true; return }
        SportSwitchLedger.record()
        athlete.switchSport(to: sport)
        try? modelContext.save()
        onChanged()
    }
}

/// Me → Sports: every sport the athlete plays, which one is active, and
/// each one's own position and season.
struct SportsManagerSheet: View {
    let athlete: Athlete
    let onChanged: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingAdd = false
    @State private var editing: AthleteSport?
    @State private var pendingRemoval: AthleteSport?
    @State private var showingPaywall = false
    @State private var showingChange = false

    private var canAdd: Bool { ProGate.canAddSport(isPro: ProAccess.isPro, currentSportCount: athlete.sports.count) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenTitle("Your sports", subtitle: "Play more than one? Add them all. The app follows the active sport — switch any time from the top of Today, Plan or Improve.")
                    ForEach(athlete.sortedSports) { sport in
                        sportCard(sport)
                    }
                    if !ProAccess.isPro {
                        Button {
                            if SportSwitchLedger.canSwitch { showingChange = true } else { showingPaywall = true }
                        } label: {
                            Label("Change sport", systemImage: "arrow.left.arrow.right")
                        }
                        .buttonStyle(.primary)
                    }
                    Button {
                        if canAdd { showingAdd = true } else { showingPaywall = true }
                    } label: {
                        Label(canAdd ? "Add a sport" : "Add another sport with Pro", systemImage: canAdd ? "plus" : "crown.fill")
                    }
                    .buttonStyle(canAdd ? .primary : .secondary)
                    if !canAdd {
                        Text("Free covers one sport, and you can change it \(ProLimits.freeSportSwitchesPerMonth) times a month\(SportSwitchLedger.remaining.map { " (\($0) left)" } ?? ""). Pro lets you add every sport you play and switch between them any time.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .appScreen()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.ink)
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddSportSheet(athlete: athlete, onSaved: onChanged)
            }
            .sheet(isPresented: $showingChange) {
                AddSportSheet(athlete: athlete, replacing: true, onSaved: onChanged)
            }
            .proPaywall(isPresented: $showingPaywall, athlete: athlete, feature: .multipleSports)
            .sheet(item: $editing) { sport in
                SportSettingsSheet(sport: sport, onSaved: onChanged)
            }
            .confirmationDialog(
                "Remove this sport?", isPresented: Binding(
                    get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }
                ), titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) { remove() }
                Button("Cancel", role: .cancel) { pendingRemoval = nil }
            } message: {
                Text("Your logged workouts stay. Games for this sport are removed.")
            }
        }
    }

    private func sportCard(_ sport: AthleteSport) -> some View {
        let info = allSportsBySlug[sport.sportSlug]
        let isActive = sport.id == athlete.activeSport?.id
        let position = sport.positionSlug.flatMap { slug in info?.positions.first { $0.slug == slug }?.name }
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: SportIcon.name(for: sport.sportSlug))
                    .font(.title3)
                    .foregroundStyle(isActive ? AppTheme.inkInverse : AppTheme.ink)
                    .frame(width: 48, height: 48)
                    .background(isActive ? AppTheme.ink : AppTheme.fill, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(info?.name ?? displayName(forSlug: sport.sportSlug))
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                        if isActive {
                            Tag("Active", color: AppTheme.green)
                        }
                    }
                    Text(position ?? "No specific position")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                    Text("Season \(sport.seasonStart.formatted(.dateTime.month(.abbreviated).day())) – \(sport.seasonEnd.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                if !isActive {
                    Button("Switch to it") {
                        guard SportSwitchLedger.canSwitch else { showingPaywall = true; return }
                        SportSwitchLedger.record()
                        athlete.switchSport(to: sport)
                        try? modelContext.save()
                        onChanged()
                    }
                    .buttonStyle(.primary)
                }
                Button("Edit") { editing = sport }
                    .buttonStyle(.secondary)
                if athlete.sports.count > 1 {
                    Button {
                        pendingRemoval = sport
                    } label: {
                        Image(systemName: "trash")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.red)
                            .frame(width: 52, height: 52)
                            .background(AppTheme.fill, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove sport")
                }
            }
        }
        .cardStyle(padding: 16)
    }

    private func remove() {
        guard let sport = pendingRemoval else { return }
        let wasActive = sport.id == athlete.activeSport?.id
        for game in athlete.competitions where game.sportSlug == sport.sportSlug {
            modelContext.delete(game)
        }
        modelContext.delete(sport)
        pendingRemoval = nil
        if wasActive, let next = athlete.sports.first(where: { $0.id != sport.id }) {
            athlete.switchSport(to: next)
        }
        try? modelContext.save()
        onChanged()
    }
}

/// Add another sport: pick it, the position, the season — and it becomes
/// the active sport straight away.
struct AddSportSheet: View {
    let athlete: Athlete
    /// Free: the new sport replaces the current one (one of the month's changes).
    var replacing = false
    let onSaved: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    @State private var sportSlug: String?
    @State private var positionSlug: String?
    @State private var seasonStart = Date.now
    @State private var seasonEnd = Date.now

    private var sport: SportInfo? { sportSlug.flatMap { allSportsBySlug[$0] } }
    private var alreadyPlays: Bool { athlete.sports.contains { $0.sportSlug == sportSlug } }

    var body: some View {
        switch step {
        case 0:
            StepScaffold(
                progress: 0.33, title: replacing ? "Change sport" : "Add a sport",
                subtitle: alreadyPlays ? "You already have this sport." : (replacing ? (SportSwitchLedger.summary.map { "Your plan switches to the new sport. \($0)." } ?? "Your plan switches to the new sport.") : "Which other sport do you play?"),
                buttonTitle: "Next", buttonEnabled: sport != nil && !alreadyPlays, onBack: { dismiss() }, onContinue: {
                    guard let sport else { return }
                    let defaults = SeasonDefaults.dates(for: sport)
                    seasonStart = defaults.start
                    seasonEnd = defaults.end
                    positionSlug = nil
                    step = sport.positions.isEmpty ? 2 : 1
                }
            ) {
                SportChooser(selection: $sportSlug)
            }
        case 1:
            if let sport {
                StepScaffold(progress: 0.66, title: "Position", subtitle: sport.name, buttonTitle: "Next",
                             onBack: { step = 0 }, onContinue: { step = 2 }) {
                    PositionChooser(sport: sport, selection: $positionSlug)
                }
            }
        default:
            StepScaffold(progress: 1, title: "Season dates", subtitle: "When does your \(sport?.name.lowercased() ?? "") season run? Your plan's phases hang off these.",
                         buttonTitle: replacing ? "Change sport" : "Add sport", onBack: { step = sport?.positions.isEmpty == false ? 1 : 0 }, onContinue: save) {
                SeasonEditor(start: $seasonStart, end: $seasonEnd)
            }
        }
    }

    private func save() {
        guard let sport, !alreadyPlays else { return }
        let added = AthleteSport(
            sportSlug: sport.slug, positionSlug: positionSlug,
            seasonStart: seasonStart, seasonEnd: max(seasonStart, seasonEnd), isPrimary: true, athlete: athlete
        )
        modelContext.insert(added)
        if replacing {
            SportSwitchLedger.record()
            for old in athlete.sports where old.id != added.id { modelContext.delete(old) }
        }
        athlete.switchSport(to: added)
        try? modelContext.save()
        let slug = sport.slug
        Task { await SportPackInstaller.install(slug: slug, context: modelContext) }
        onSaved()
        dismiss()
    }
}

/// One sport's own settings: position and season.
struct SportSettingsSheet: View {
    let sport: AthleteSport
    let onSaved: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var positionSlug: String?
    @State private var start = Date.now
    @State private var end = Date.now

    private var info: SportInfo? { allSportsBySlug[sport.sportSlug] }

    var body: some View {
        StepScaffold(title: info?.name ?? displayName(forSlug: sport.sportSlug), subtitle: "Position and season for this sport.",
                     buttonTitle: "Save", onBack: { dismiss() }, onContinue: save) {
            if let info, !info.positions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Position")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    PositionChooser(sport: info, selection: $positionSlug)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Season")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                SeasonEditor(start: $start, end: $end)
            }
        }
        .onAppear {
            positionSlug = sport.positionSlug
            start = sport.seasonStart
            end = sport.seasonEnd
        }
    }

    private func save() {
        sport.positionSlug = positionSlug
        sport.seasonStart = start
        sport.seasonEnd = max(start, end)
        try? modelContext.save()
        onSaved()
        dismiss()
    }
}
