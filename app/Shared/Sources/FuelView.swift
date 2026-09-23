import SwiftData
import SwiftUI

/// §13 in one screen: water, today's plate in simple portions, what and when
/// to eat around today's session or game, and a quick meal log. Fuelling,
/// never cutting — there is no calorie number and no weight anywhere here.
struct FuelView: View {
    let athlete: Athlete
    let todaysSession: GeneratedSession?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("trainingStartMinutes") private var trainingStartMinutes = FuelEngine.defaultTrainingStartMinutes
    @AppStorage("gameStartMinutes") private var gameStartMinutes = 17 * 60
    @State private var showingLogMeal = false
    @State private var waterTaps = 0

    private var calendar: Calendar { .current }

    private var gameToday: Competition? {
        athlete.competitions.first { calendar.isDateInToday($0.date) }
    }

    private var trainingMinutes: Int {
        todaysSession?.estimatedMinutes ?? (gameToday != nil ? 60 : 0)
    }

    private var meals: [MealLog] { MealStore.meals(of: athlete, on: .now) }
    private var glasses: Int { MealStore.glasses(of: athlete, on: .now) }
    private var glassTarget: Int { FuelEngine.hydrationTarget(trainingMinutes: trainingMinutes) }
    private var targets: PlateTargets { FuelEngine.plateTargets(trainingMinutes: trainingMinutes, isGameDay: gameToday != nil) }

    private func time(fromMinutes minutes: Int) -> Date {
        calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
    }

    private func minutesBinding(_ storage: Binding<Int>) -> Binding<Date> {
        Binding(
            get: { time(fromMinutes: storage.wrappedValue) },
            set: { date in
                let parts = calendar.dateComponents([.hour, .minute], from: date)
                storage.wrappedValue = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }

    private var timeline: [FuelTip] {
        if let gameToday {
            return FuelEngine.gameDayTimeline(gameStart: time(fromMinutes: gameStartMinutes), isTournament: gameToday.kind == .tournament)
        }
        if let todaysSession {
            return FuelEngine.sessionTimeline(start: time(fromMinutes: trainingStartMinutes), minutes: todaysSession.estimatedMinutes)
        }
        return []
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle("Fuel", subtitle: "Eat enough for what you're doing. That's the whole idea.")
                    hydrationCard
                    plateCards
                    Button {
                        showingLogMeal = true
                    } label: {
                        Label("Log a meal", systemImage: "plus")
                    }
                    .buttonStyle(.primary)

                    timelineSection
                    if !meals.isEmpty { mealsSection }
                    plateGuideCard
                    noteCard
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .appScreen()
            .sensoryFeedback(.increase, trigger: waterTaps)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.ink)
                }
            }
            .sheet(isPresented: $showingLogMeal) {
                MealLogSheet(athlete: athlete, suggestedSlot: suggestedSlot)
            }
        }
    }

    /// The slot that most likely applies right now.
    private var suggestedSlot: MealSlot {
        let hour = calendar.component(.hour, from: .now)
        switch hour {
        case ..<10: return .breakfast
        case 10..<14: return .lunch
        case 14..<17: return .snack
        default: return .dinner
        }
    }

    // MARK: - Hydration

    private var hydrationCard: some View {
        HStack(spacing: 18) {
            RingView(progress: Double(glasses) / Double(max(glassTarget, 1)), color: AppTheme.blue, lineWidth: 10) {
                VStack(spacing: 0) {
                    Text("\(glasses)")
                        .font(.title2.bold())
                        .foregroundStyle(AppTheme.ink)
                        .contentTransition(.numericText())
                    Text("of \(glassTarget)")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .frame(width: 96, height: 96)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(glasses) of \(glassTarget) glasses of water")

            VStack(alignment: .leading, spacing: 8) {
                Text("Water")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                Text(trainingMinutes > 0 ? "Training today, so a bit more than usual." : "A normal day's target.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                HStack(spacing: 10) {
                    Button { changeWater(-1) } label: {
                        Image(systemName: "minus")
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.fill, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove a glass")
                    Button { changeWater(1) } label: {
                        Label("Glass", systemImage: "drop.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(AppTheme.inkInverse)
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                            .background(AppTheme.ink, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add a glass of water")
                }
            }
            Spacer(minLength: 0)
        }
        .cardStyle()
    }

    private func changeWater(_ delta: Int) {
        _ = try? MealStore(modelContext: modelContext).addWater(athlete: athlete, glasses: delta)
        waterTaps += 1
    }

    // MARK: - Plate

    private var plateCards: some View {
        let protein = meals.reduce(0) { $0 + $1.proteinPortions }
        let carbs = meals.reduce(0) { $0 + $1.carbPortions }
        let colour = meals.reduce(0) { $0 + $1.colourPortions }
        return HStack(spacing: 12) {
            RingStatCard(value: "\(protein)/\(targets.protein)", label: "Protein", progress: Double(protein) / Double(targets.protein), color: AppTheme.brand, systemImage: "fish.fill")
            RingStatCard(value: "\(carbs)/\(targets.carbs)", label: "Carbs", progress: Double(carbs) / Double(targets.carbs), color: AppTheme.amber, systemImage: "leaf.fill")
            RingStatCard(value: "\(colour)/\(targets.colour)", label: "Colour", progress: Double(colour) / Double(targets.colour), color: AppTheme.green, systemImage: "carrot.fill")
        }
    }

    // MARK: - Timeline

    @ViewBuilder
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(gameToday != nil ? "Game-day fuelling" : "Around today's session")
            }
            if gameToday != nil {
                DatePicker("Game starts", selection: minutesBinding($gameStartMinutes), displayedComponents: .hourAndMinute)
                    .tint(AppTheme.ink)
                    .cardStyle(padding: 14)
            } else if todaysSession != nil {
                DatePicker("Training starts", selection: minutesBinding($trainingStartMinutes), displayedComponents: .hourAndMinute)
                    .tint(AppTheme.ink)
                    .cardStyle(padding: 14)
            }
            if timeline.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "moon.zzz.fill")
                        .foregroundStyle(AppTheme.purple)
                    Text("Rest day: regular meals with protein at each one help you recover. No need to eat less just because you're not training.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .cardStyle(padding: 16)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(timeline.enumerated()), id: \.element.id) { index, tip in
                        tipRow(tip, isLast: index == timeline.count - 1)
                    }
                }
                .cardStyle(padding: 16)
            }
        }
    }

    private func tipRow(_ tip: FuelTip, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Image(systemName: tip.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.inkInverse)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.ink, in: Circle())
                if !isLast {
                    Rectangle()
                        .fill(AppTheme.hairline)
                        .frame(width: 2)
                        .frame(minHeight: 24)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                if let time = tip.time {
                    Text(time.formatted(date: .omitted, time: .shortened))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Text(tip.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.ink)
                Text(tip.detail)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : 14)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Meals

    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Today's meals")
            ForEach(meals) { meal in
                HStack(spacing: 14) {
                    Image(systemName: meal.slot.systemImage)
                        .font(.title3)
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 52, height: 52)
                        .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(meal.slot.title)
                                .font(.headline)
                                .foregroundStyle(AppTheme.ink)
                            Spacer()
                            Text(meal.date.formatted(date: .omitted, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        HStack(spacing: 6) {
                            Tag("Protein \(meal.proteinPortions)", color: AppTheme.brand)
                            Tag("Carbs \(meal.carbPortions)", color: AppTheme.amber)
                            Tag("Colour \(meal.colourPortions)", color: AppTheme.green)
                        }
                        if let note = meal.note {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                    Button {
                        try? MealStore(modelContext: modelContext).delete(meal)
                    } label: {
                        Image(systemName: "trash")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Delete meal")
                }
                .cardStyle(padding: 12)
            }
        }
    }

    // MARK: - Guidance

    private var plateGuideCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Building a plate")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)
            guideRow("fish.fill", AppTheme.brand, "Protein — a palm", "Chicken, fish, eggs, beans, yogurt, tofu. One at every meal.")
            guideRow("leaf.fill", AppTheme.amber, "Carbs — a fist or two", "Rice, pasta, potatoes, bread, oats. More on big training and game days.")
            guideRow("carrot.fill", AppTheme.green, "Colour — the rest", "Fruit and veg, as many colours as you can.")
        }
        .cardStyle()
    }

    private func guideRow(_ icon: String, _ tint: Color, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.13), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    private var noteCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "stethoscope")
                .foregroundStyle(AppTheme.secondaryText)
            Text(FuelEngine.standingNote)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .cardStyle(padding: 16)
    }
}

/// Log one meal: when, and how many simple portions of each part.
struct MealLogSheet: View {
    let athlete: Athlete
    let suggestedSlot: MealSlot

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var slot: MealSlot = .lunch
    @State private var protein = 1
    @State private var carbs = 1
    @State private var colour = 1
    @State private var note = ""

    var body: some View {
        StepScaffold(
            title: "Log a meal", subtitle: "Count portions, not calories: a palm of protein, a fist of carbs, a fist of fruit or veg.",
            buttonTitle: "Save meal", onBack: { dismiss() }, onContinue: save
        ) {
            FlowLayout(spacing: 8) {
                ForEach(MealSlot.mealSlots, id: \.self) { value in
                    Button { slot = value } label: { Chip(value.title, isSelected: slot == value) }
                        .buttonStyle(.plain)
                }
            }
            VStack(spacing: 12) {
                BigStepper(label: "Protein portions", value: "\(protein)", onMinus: { protein = max(0, protein - 1) }, onPlus: { protein = min(3, protein + 1) })
                BigStepper(label: "Carb portions", value: "\(carbs)", onMinus: { carbs = max(0, carbs - 1) }, onPlus: { carbs = min(3, carbs + 1) })
                BigStepper(label: "Fruit & veg portions", value: "\(colour)", onMinus: { colour = max(0, colour - 1) }, onPlus: { colour = min(3, colour + 1) })
            }
            TextField("What was it? (optional)", text: $note)
                .padding(16)
                .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))
        }
        .onAppear { slot = suggestedSlot }
    }

    private func save() {
        _ = try? MealStore(modelContext: modelContext).logMeal(
            athlete: athlete, slot: slot, protein: protein, carbs: carbs, colour: colour, note: note
        )
        dismiss()
    }
}
