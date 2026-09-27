import SwiftUI

/// Workout → Build a new gym plan. First the choice (generate it or build
/// it yourself); a generated plan can be randomized as a whole, or one
/// exercise at a time with ♻︎ — always from the athlete's own equipment,
/// sport, position, age and experience, and for the same spot in the
/// workout. Saving replaces last plan's gym days (logged workouts stay).
struct NewGymPlanSheet: View {
    let athlete: Athlete
    /// How many gym days the current week has (for building your own).
    let gymDays: Int
    let onChanged: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = .choose
    @State private var variant = PlanVariant.current + 1
    @State private var input: PlanGeneratorInput?
    @State private var week: GeneratedWeek?
    /// Days where an exercise was swapped by hand (saved as the athlete's own version).
    @State private var changedDays: Set<Int> = []
    /// Per exercise spot (day-order), how many times ♻︎ was tapped.
    @State private var turns: [String: Int] = [:]
    @State private var building: Int?
    @State private var showingPaywall = false
    @State private var catalogue = Catalogue()

    enum Step { case choose, generated, own }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .choose: choose
                case .generated: generated
                case .own: own
                }
            }
            .appScreen()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .proFeature(isPresented: $showingPaywall, athlete: athlete, feature: .workoutEditor)
        .sheet(item: Binding(get: { building.map(DayBox.init) }, set: { building = $0?.day })) { box in
            WorkoutEditorView(heading: "Gym day \(box.day + 1)", workout: CustomWorkout(title: "Gym day \(box.day + 1)", items: []),
                              sportSlug: athlete.activeSport?.sportSlug) { saved in
                PlanCustomizationStore.setWorkout(saved, for: .gym(box.day))
                changedDays.insert(box.day)
                onChanged()
            }
        }
        .task { catalogue = CatalogueLoader.load(from: AppConfig.packsDirectory()) }
    }

    struct DayBox: Identifiable {
        let day: Int
        var id: Int { day }
    }

    // MARK: - The choice

    private var equipmentLine: String {
        athlete.equipmentAvailable.isEmpty ? "Bodyweight only" : "Your \(athlete.equipmentAvailable.count) pieces of equipment"
    }

    private var choose: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenTitle("New gym plan", subtitle: "\(equipmentLine), your sport and your level. Workouts you logged stay.")
                Button { generate(randomizing: false) } label: {
                    OptionRow(title: "Generate it for me", subtitle: "Then randomize it, or swap single exercises", systemImage: "sparkles", isSelected: false)
                }
                .buttonStyle(.plain)
                Button {
                    if ProAccess.isPro { step = .own } else { showingPaywall = true }
                } label: {
                    OptionRow(title: "Build it myself", subtitle: "Pick every exercise for each gym day", systemImage: "hand.point.up.left.fill", isSelected: false)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
    }

    // MARK: - Generated

    private var generated: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    ScreenTitle("Your new plan", subtitle: equipmentLine)
                    Spacer()
                    Button { generate(randomizing: true) } label: {
                        Label("Randomize", systemImage: "dice.fill")
                            .font(.headline)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(AppTheme.fill, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.ink)
                }
                if let week {
                    if week.sessions.allSatisfy({ $0.items.isEmpty }) {
                        Text("Nothing fits your equipment yet. Add equipment in Me → Training Setup.")
                            .font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                    }
                    ForEach(Array(week.sessions.enumerated()), id: \.offset) { dayIndex, session in
                        dayCard(dayIndex, session)
                    }
                }
                Button("Use this plan") { save() }
                    .buttonStyle(.primary)
                    .disabled(week == nil)
            }
            .padding(20)
        }
    }

    private func dayCard(_ dayIndex: Int, _ session: GeneratedSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Day \(dayIndex + 1) · \(session.title)").font(.headline).foregroundStyle(AppTheme.ink)
                Spacer()
                Text("\(session.estimatedMinutes) min").font(.subheadline).foregroundStyle(AppTheme.secondaryText)
            }
            ForEach(session.items, id: \.order) { item in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(catalogue.item(item.itemSlug)?.name ?? displayName(forSlug: item.itemSlug))
                            .font(.body.weight(.semibold)).foregroundStyle(AppTheme.ink)
                        Text(DoseFormatter.text(item.dose)).font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                    }
                    Spacer(minLength: 0)
                    Button { recycle(day: dayIndex, item: item) } label: {
                        Image(systemName: "arrow.2.circlepath")
                            .font(.headline)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.fill, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.ink)
                    .accessibilityLabel("Swap \(catalogue.item(item.itemSlug)?.name ?? item.itemSlug) for another exercise")
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Build your own

    private var own: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenTitle("Build it yourself", subtitle: "Tap a gym day and add the exercises you want.")
                ForEach(0..<max(gymDays, 1), id: \.self) { day in
                    Button { building = day } label: {
                        ListRow(systemImage: "dumbbell.fill", color: AppTheme.ink, title: "Gym day \(day + 1)",
                                detail: changedDays.contains(day) ? "Built" : "Tap to build")
                            .cardStyle(padding: 12)
                    }
                    .buttonStyle(.plain)
                }
                Button("Done") {
                    onChanged()
                    dismiss()
                }
                .buttonStyle(.primary)
            }
            .padding(20)
        }
    }

    // MARK: - Actions

    /// A new plan: a new variant, leaving out what the last one had.
    private func generate(randomizing: Bool) {
        let previous = Set((week ?? WeeklyPlan.generate(for: athlete))?.sessions.flatMap { $0.items.map(\.itemSlug) } ?? [])
        if randomizing { variant += 1 }
        guard let fresh = WeeklyPlan.input(for: athlete, variant: variant, avoid: previous) else { return }
        input = fresh
        week = PlanGenerator.generate(fresh)
        changedDays = []
        turns = [:]
        step = .generated
    }

    /// ♻︎: another exercise for the same spot.
    private func recycle(day: Int, item: GeneratedPlannedItem) {
        guard let input, var current = week, current.sessions.indices.contains(day) else { return }
        let session = current.sessions[day]
        let key = "\(day)-\(item.order)"
        let turn = (turns[key] ?? 0) + 1
        turns[key] = turn
        guard let replacement = PlanGenerator.replacement(for: item, in: session, input: input, turn: turn) else { return }
        var items = session.items
        if let index = items.firstIndex(where: { $0.order == item.order }) { items[index] = replacement }
        let minutes = items.reduce(0) { $0 + PlanGenerator.estimatedMinutes(dose: $1.dose, restSec: $1.restSec) }
        var updated = GeneratedSession(date: session.date, title: session.title, focusQualities: session.focusQualities,
                                       estimatedMinutes: minutes, items: items)
        updated.slot = session.slot
        var sessions = current.sessions
        sessions[day] = updated
        current = GeneratedWeek(phase: current.phase, weekStart: current.weekStart, sessions: sessions)
        week = current
        changedDays.insert(day)
    }

    /// The new plan replaces the old one: its variant, and the athlete's own
    /// versions only for days where they swapped an exercise.
    private func save() {
        guard let week else { return }
        for day in 0..<6 { PlanCustomizationStore.setWorkout(nil, for: .gym(day)) }
        PlanVariant.set(variant)
        for (index, session) in week.sessions.enumerated() where changedDays.contains(index) {
            PlanCustomizationStore.setWorkout(CustomWorkout(session: session), for: .gym(session.slot ?? index))
        }
        onChanged()
        dismiss()
    }
}
