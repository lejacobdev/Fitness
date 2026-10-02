import SwiftData
import SwiftUI
#if os(iOS)
import UIKit
#endif

/// §15: "The live session screen gets the most attention after Today:
/// current item with its pose animation and muscle map, prefilled targets
/// from last time, big steppers, an automatic rest timer, collapsible cues,
/// next and previous. One-handed, sweaty-hands, glanceable, screen stays
/// awake. It ends with the single RPE question and nothing else."
///
/// Started from today's plan it walks that plan item by item; started empty
/// ("Log a workout") it's a free log where exercises are added as you go.
@MainActor
public struct LiveSessionView: View {
    let athlete: Athlete
    let apiClient: APIClient
    let planned: GeneratedSession?
    /// Which kind of workout this is, for the Progress calendar's colours.
    let kind: WorkoutKind?
    /// Training together: everyone's progress shows at the top.
    let partnerCode: String?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var session: Session?
    @State private var catalogue = Catalogue()
    @State private var queue: [GeneratedPlannedItem] = []
    @State private var index = 0
    @State private var setsLogged: [String: Int] = [:]
    @State private var reps = 8
    @State private var weightKg: Double = 0
    @State private var seconds = 30
    @State private var distanceM: Double = 20
    @State private var contacts = 10
    @State private var restRemaining = 0
    @State private var restTotal = 0
    @State private var restTask: Task<Void, Never>?
    @State private var showingCues = false
    @State private var showingPicker = false
    @State private var showingEndOptions = false
    @State private var showingRPE = false
    @State private var rpe = 6
    @State private var loggedCount = 0
    @State private var restEndedCount = 0
    @State private var startedAt = Date.now
    /// Why today's target differs from last time (progressive overload).
    @State private var targetNote: String?
    /// "New best: 45 kg" after a set heavier than ever before.
    @State private var bestNote: String?
    @State private var bestCount = 0
    @State private var heartRate: HeartRateSummary?
    @AppStorage(WeightUnit.storageKey) private var unitRaw = WeightUnit.current.rawValue

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .kg }

    /// Every planned set is logged — time to finish.
    private var allDone: Bool {
        !queue.isEmpty && queue.allSatisfy { setsLogged[$0.itemSlug, default: 0] >= $0.dose.sets }
    }

    public init(athlete: Athlete, apiClient: APIClient, planned: GeneratedSession? = nil, kind: WorkoutKind? = nil, partnerCode: String? = nil) {
        self.athlete = athlete
        self.apiClient = apiClient
        self.planned = planned
        self.kind = kind
        self.partnerCode = partnerCode
    }

    private var current: GeneratedPlannedItem? {
        queue.indices.contains(index) ? queue[index] : nil
    }

    private var currentItem: CatalogueItem? {
        current.flatMap { catalogue.item($0.itemSlug) }
    }

    private var totalTargetSets: Int {
        max(queue.reduce(0) { $0 + $1.dose.sets }, 1)
    }

    private var totalLogged: Int {
        setsLogged.values.reduce(0, +)
    }

    public var body: some View {
        VStack(spacing: 0) {
            topBar
            if let current {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if let partnerCode {
                            PartnerStrip(code: partnerCode, done: queue.filter { setsLogged[$0.itemSlug, default: 0] >= $0.dose.sets }.count,
                                         total: queue.count, finished: false)
                        }
                        if loggedCount == 0 {
                            TipCard(id: "live", icon: "hand.tap.fill", title: "How a workout works",
                                    message: "Do a set, log it, rest. Tap Finish when you're done.")
                        }
                        if allDone {
                            doneCard
                        }
                        poseHero
                        itemHeader(current)
                        if restRemaining > 0 {
                            restCard
                        } else {
                            doseControls(current)
                        }
                        cuesCard
                        upNext
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)
                bottomBar(current)
            } else {
                emptyState
            }
        }
        .appScreen()
        .sensoryFeedback(.success, trigger: loggedCount)
        .sensoryFeedback(.warning, trigger: restEndedCount)
        .task { await start() }
        .onDisappear {
            restTask?.cancel()
            setIdleTimerDisabled(false)
        }
        .sheet(isPresented: $showingPicker) {
            ExercisePickerSheet(catalogue: catalogue, sports: SportVisibility.sports(for: athlete)) { item in
                add(item)
            }
        }
        .sheet(isPresented: $showingRPE) {
            RPEPromptView(rpe: $rpe, heartRate: heartRate) { finish() }
                .task {
                    guard let session else { return }
                    heartRate = await HealthKitManager.shared.heartRate(from: session.startedAt, to: .now)
                    // A watch saw the effort: start the question from there.
                    if let heartRate {
                        rpe = WearableLoad.effort(averageHeartRate: Double(heartRate.average), minutes: Int(Date.now.timeIntervalSince(session.startedAt) / 60),
                                                  age: PlanGenerator.ageInYears(birthDate: athlete.birthDate, now: .now))
                    }
                }
                .presentationDetents([.large])
                .interactiveDismissDisabled()
        }
        .confirmationDialog("End this session?", isPresented: $showingEndOptions, titleVisibility: .visible) {
            Button("Finish and save") { showingRPE = true }
            Button("Discard session", role: .destructive) { discard() }
            Button("Keep training", role: .cancel) {}
        }
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack(spacing: 14) {
            CircleIconButton(systemImage: "xmark", accessibilityLabel: "End session") {
                if totalLogged == 0 {
                    discard()
                } else {
                    showingEndOptions = true
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                StepProgressBar(progress: Double(totalLogged) / Double(totalTargetSets))
                TimelineView(.periodic(from: startedAt, by: 1)) { context in
                    Text(elapsedText(context.date))
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            Button(totalLogged == 0 ? "Close" : "Finish") {
                if totalLogged == 0 { discard() } else { showingRPE = true }
            }
            .font(.headline)
            .foregroundStyle(AppTheme.ink)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func elapsedText(_ now: Date) -> String {
        let total = Int(now.timeIntervalSince(startedAt))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var poseHero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .fill(AppTheme.card)
                .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4)
            HStack(spacing: 8) {
                if let pattern = currentItem?.posePattern {
                    RigPoseView(pattern: pattern, muscles: currentItem?.muscles ?? [:])
                        .frame(maxWidth: .infinity)
                }
                if let currentItem {
                    MuscleMapView(side: .front, weights: currentItem.muscles)
                        .frame(width: 80)
                        .accessibilityHidden(true)
                }
            }
            .padding(18)
        }
        .frame(height: 230)
        .id(current?.itemSlug)
        .transition(.opacity)
    }

    /// V5: "03 / 08", the name big, the dose as one tracked line, rest and
    /// why underneath.
    private func itemHeader(_ current: GeneratedPlannedItem) -> some View {
        let done = setsLogged[current.itemSlug, default: 0]
        return VStack(alignment: .leading, spacing: 10) {
            Text(String(format: "%02d / %02d", index + 1, queue.count))
                .font(.footnote.weight(.bold).monospacedDigit())
                .tracking(2)
                .foregroundStyle(AppTheme.brightRed)
                .accessibilityLabel("Exercise \(index + 1) of \(queue.count)")
            Text(currentItem?.name ?? displayName(forSlug: current.itemSlug))
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(DoseFormatter.text(current.dose).uppercased())
                .font(.title3.weight(.bold).monospacedDigit())
                .tracking(1.2)
                .foregroundStyle(AppTheme.ink)
            HStack(spacing: 18) {
                Text(done >= current.dose.sets ? "ALL SETS DONE" : "SET \(min(done + 1, current.dose.sets)) OF \(current.dose.sets)")
                    .foregroundStyle(done >= current.dose.sets ? AppTheme.green : AppTheme.ink)
                if current.restSec > 0 {
                    Text("REST \(current.restSec)S")
                }
                if let why = whyLine {
                    Text("WHY · \(why.uppercased())")
                        .lineLimit(1)
                }
            }
            .font(.caption.weight(.bold).monospacedDigit())
            .tracking(1.4)
            .foregroundStyle(AppTheme.secondaryText)
            if let bestNote {
                Label(bestNote, systemImage: "trophy.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.amber)
                    .sensoryFeedback(.success, trigger: bestCount)
            }
            if let targetNote, done == 0 {
                Label(targetNote, systemImage: "arrow.up.right")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    /// What the exercise is mainly for, in a word or two ("Power").
    private var whyLine: String? {
        guard let top = currentItem?.qualities.max(by: { $0.value < $1.value })?.key else { return nil }
        return qualitiesBySlug[top]?.shortName
    }

    // MARK: - Logging

    @ViewBuilder
    private func doseControls(_ current: GeneratedPlannedItem) -> some View {
        VStack(spacing: 12) {
            switch current.dose.kind {
            case "reps":
                BigStepper(label: "Reps", value: "\(reps)", onMinus: { reps = max(1, reps - 1) }, onPlus: { reps = min(100, reps + 1) })
                BigStepper(
                    label: "Weight added", value: weightKg < 0.1 ? "Bodyweight" : unit.format(kg: weightKg),
                    onMinus: { weightKg = max(0, weightKg - unit.stepKg) }, onPlus: { weightKg = min(400, weightKg + unit.stepKg) }
                )
                HStack(spacing: 6) {
                    Text("Weights in")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                    ForEach(WeightUnit.allCases, id: \.self) { option in
                        Button { unitRaw = option.rawValue } label: { Chip(option == .lb ? "lb" : "kg", isSelected: unit == option) }
                            .buttonStyle(.plain)
                    }
                }
            case "time":
                BigStepper(label: "Seconds", value: "\(seconds)", onMinus: { seconds = max(5, seconds - 5) }, onPlus: { seconds = min(900, seconds + 5) })
            case "distance":
                BigStepper(label: "Distance", value: Measure.distance(m: distanceM), onMinus: { distanceM = max(5, distanceM - 5) }, onPlus: { distanceM = min(2000, distanceM + 5) })
            case "contacts":
                BigStepper(label: "Contacts", value: "\(contacts)", onMinus: { contacts = max(1, contacts - 1) }, onPlus: { contacts = min(100, contacts + 1) })
            default:
                EmptyView()
            }
        }
    }

    private var doneCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(AppTheme.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Every set done")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                Text("Great work. Tap Finish workout to save it — or add an exercise if you want more.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 16)
    }

    private var restCard: some View {
        VStack(spacing: 14) {
            Text("Rest")
                .font(.headline)
                .foregroundStyle(AppTheme.secondaryText)
            RingView(progress: restTotal > 0 ? Double(restRemaining) / Double(restTotal) : 0, color: AppTheme.ink, lineWidth: 12) {
                Text(String(format: "%d:%02d", restRemaining / 60, restRemaining % 60))
                    .font(.system(size: 40, weight: .bold).monospacedDigit())
                    .foregroundStyle(AppTheme.ink)
                    .contentTransition(.numericText())
            }
            .frame(width: 180, height: 180)
            ButtonRow {
                Button("+15s") {
                    restRemaining += 15
                    restTotal += 15
                }
                .buttonStyle(.secondary)
                Button("Skip rest") { endRest(silently: true) }
                    .buttonStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    @ViewBuilder
    private var cuesCard: some View {
        if let currentItem, !currentItem.cues.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showingCues.toggle() }
                } label: {
                    HStack {
                        Label("Coaching cues", systemImage: "megaphone.fill")
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                        Spacer()
                        Image(systemName: showingCues ? "chevron.up" : "chevron.down")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                .buttonStyle(.plain)
                if showingCues {
                    ForEach(currentItem.cues + currentItem.mistakes.map { "Avoid: \($0)" }, id: \.self) { cue in
                        Text("•  \(cue)")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.ink.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if let first = currentItem.cues.first {
                    Text(first)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .cardStyle(padding: 16)
        }
    }

    private var upNext: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("All exercises in this workout")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Button {
                    showingPicker = true
                } label: {
                    Label("Add exercise", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                }
            }
            ForEach(Array(queue.enumerated()), id: \.offset) { position, item in
                let done = setsLogged[item.itemSlug, default: 0]
                Button {
                    jump(to: position)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: done >= item.dose.sets ? "checkmark.circle.fill" : (position == index ? "play.circle.fill" : "circle"))
                            .foregroundStyle(done >= item.dose.sets ? AppTheme.green : AppTheme.ink)
                        Text(catalogue.item(item.itemSlug)?.name ?? displayName(forSlug: item.itemSlug))
                            .font(.subheadline.weight(position == index ? .bold : .regular))
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(1)
                        Spacer()
                        Text("\(done) of \(item.dose.sets) sets")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .cardStyle(padding: 16)
    }

    private func bottomBar(_ current: GeneratedPlannedItem) -> some View {
        HStack(spacing: 12) {
            CircleIconButton(systemImage: "chevron.left", accessibilityLabel: "Previous exercise") { jump(to: index - 1) }
                .disabled(index == 0)
                .opacity(index == 0 ? 0.4 : 1)
            if allDone {
                Button("Finish workout") { showingRPE = true }
                    .buttonStyle(.primary)
            } else {
                if restRemaining > 0 {
                    Button("Skip rest") { endRest(silently: true) }
                        .buttonStyle(.secondary)
                } else {
                    Button { logSet(current) } label: { HeroCTALabel("Complete set") }
                        .buttonStyle(.primary)
                }
            }
            CircleIconButton(systemImage: "chevron.right", accessibilityLabel: "Next exercise") { jump(to: index + 1) }
                .disabled(index >= queue.count - 1)
                .opacity(index >= queue.count - 1 ? 0.4 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(AppTheme.background.opacity(0.85))
        .background(.ultraThinMaterial)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 90, height: 90)
                .background(AppTheme.card, in: Circle())
            Text("Log a workout")
                .font(.title2.bold())
                .foregroundStyle(AppTheme.ink)
            Text("Add exercises as you go. Every set is saved the moment you log it — even offline.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                showingPicker = true
            } label: {
                Label("Add first exercise", systemImage: "plus")
            }
            .buttonStyle(.primary)
            .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Actions

    private func start() async {
        catalogue = CatalogueLoader.load(from: AppConfig.packsDirectory())
        if session == nil {
            session = try? SessionLogger(modelContext: modelContext).startSession(athlete: athlete)
            if let session { SessionKinds.record(session.clientId, kind ?? (planned == nil ? nil : .gym)) }
            startedAt = session?.startedAt ?? .now
            queue = planned?.items ?? []
            prefill()
        }
        setIdleTimerDisabled(true)
        updateActivity()
    }

    /// Keeps the Lock Screen / Dynamic Island in step with the workout.
    private func updateActivity() {
        #if os(iOS) && !APP_EXTENSION
        guard let current else { return }
        let done = setsLogged[current.itemSlug, default: 0]
        let state = WorkoutActivityAttributes.ContentState(
            exercise: currentItem?.name ?? displayName(forSlug: current.itemSlug),
            detail: restRemaining > 0 ? "Rest" : "Set \(min(done + 1, current.dose.sets)) of \(current.dose.sets)",
            restEndsAt: restRemaining > 0 ? Date.now.addingTimeInterval(Double(restRemaining)) : nil,
            setsDone: totalLogged, setsTotal: totalTargetSets
        )
        WorkoutActivity.show(title: planned?.title ?? "Workout", state: state)
        #endif
    }

    private func endActivity() {
        #if os(iOS) && !APP_EXTENSION
        WorkoutActivity.end()
        #endif
    }

    private func add(_ item: CatalogueItem) {
        queue.append(GeneratedPlannedItem(
            itemSlug: item.slug, order: queue.count, dose: item.defaultDose, restSec: item.restSeconds,
            rationale: "", quality: item.primaryQuality?.id ?? ""
        ))
        jump(to: queue.count - 1)
    }

    private func jump(to position: Int) {
        guard queue.indices.contains(position) else { return }
        withAnimation(.easeInOut(duration: 0.25)) { index = position }
        endRest(silently: true)
        showingCues = false
        prefill()
        updateActivity()
    }

    /// §15: "prefilled targets from last time" — the most recent logged set
    /// of this item wins; otherwise the plan's own dose. When last time went
    /// well, the target moves on a step (ProgressionEngine).
    private func prefill() {
        guard let current else { return }
        let slug = current.itemSlug
        let descriptor = FetchDescriptor<SetLog>(predicate: #Predicate { $0.itemSlug == slug })
        let earlier = ((try? modelContext.fetch(descriptor)) ?? []).filter { $0.session?.id != session?.id }
        let previous = earlier.max { ($0.session?.startedAt ?? .distantPast) < ($1.session?.startedAt ?? .distantPast) }

        reps = previous?.reps ?? current.dose.reps ?? 8
        weightKg = previous?.weightKg ?? 0
        seconds = previous?.seconds ?? current.dose.seconds ?? 30
        distanceM = previous?.distanceM ?? current.dose.metres ?? 20
        contacts = previous?.contacts ?? current.dose.contacts ?? 10
        targetNote = nil

        guard let lastSession = previous?.session else { return }
        let lastSets = earlier.filter { $0.session?.id == lastSession.id }
            .map { LoggedSet(reps: $0.reps, weightKg: $0.weightKg, seconds: $0.seconds) }
        let age = PlanGenerator.ageInYears(birthDate: athlete.birthDate, now: .now)
        let calendar = Calendar.current
        let deload = athlete.activeSport.map { sport -> Bool in
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
            let phase = PhaseCalculator.phase(today: .now, seasonStart: sport.seasonStart, seasonEnd: sport.seasonEnd)
            return Deload.isDeloadWeek(weekStart: weekStart, anchor: athlete.createdAt, phase: phase)
        } ?? false
        // The session before that: progress needs two steady sessions in a row.
        let before = earlier.filter { ($0.session?.startedAt ?? .distantFuture) < lastSession.startedAt }
            .max { ($0.session?.startedAt ?? .distantPast) < ($1.session?.startedAt ?? .distantPast) }?.session
        let beforeSets = before.map { session in
            earlier.filter { $0.session?.id == session.id }.map { LoggedSet(reps: $0.reps, weightKg: $0.weightKg, seconds: $0.seconds) }
        }
        let painInArea = PainStore.report() != nil
        if let target = ProgressionEngine.next(last: lastSets, dose: current.dose, sessionRPE: lastSession.sessionRPE,
                                               isYouth: age < 18, stepKg: unit.stepKg, deload: deload,
                                               previous: beforeSets, previousRPE: before?.sessionRPE, painInArea: painInArea) {
            if let value = target.reps { reps = value }
            if let value = target.weightKg { weightKg = value }
            if let value = target.seconds { seconds = value }
            targetNote = target.note
        }
    }

    private func logSet(_ current: GeneratedPlannedItem) {
        guard let session else { return }
        let kind = current.dose.kind
        if kind == "reps", weightKg > 0 {
            let slug = current.itemSlug
            let descriptor = FetchDescriptor<SetLog>(predicate: #Predicate { $0.itemSlug == slug })
            let heaviest = ((try? modelContext.fetch(descriptor)) ?? []).compactMap(\.weightKg).max()
            if let heaviest, weightKg > heaviest + 0.01 {
                bestNote = "New best on \(currentItem?.name ?? displayName(forSlug: slug)): \(unit.format(kg: weightKg))"
                bestCount += 1
            }
        }
        let setIndex = setsLogged[current.itemSlug, default: 0]
        _ = try? SessionLogger(modelContext: modelContext).logSet(
            session: session, itemSlug: current.itemSlug, setIndex: setIndex,
            reps: kind == "reps" ? reps : nil,
            weightKg: kind == "reps" && weightKg > 0 ? weightKg : nil,
            seconds: kind == "time" ? seconds : nil,
            distanceM: kind == "distance" ? distanceM : nil,
            contacts: kind == "contacts" ? contacts : nil
        )
        setsLogged[current.itemSlug] = setIndex + 1
        loggedCount += 1

        if setIndex + 1 >= current.dose.sets, index < queue.count - 1 {
            // All sets done: move on, resting on the way.
            jump(to: index + 1)
            startRest(current.restSec)
        } else {
            startRest(current.restSec)
        }
    }

    private func startRest(_ duration: Int) {
        restTask?.cancel()
        restTotal = max(duration, 1)
        restRemaining = duration
        updateActivity()
        restTask = Task {
            while restRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                restRemaining -= 1
            }
            restEndedCount += 1
            updateActivity()
        }
    }

    private func endRest(silently: Bool) {
        restTask?.cancel()
        restRemaining = 0
        if !silently { restEndedCount += 1 }
    }

    private func finish() {
        endActivity()
        if let partnerCode {
            let total = queue.count
            Task { await PartnerWorkouts.report(code: partnerCode, done: total, total: total, finished: true) }
        }
        guard let session else { return }
        try? SessionLogger(modelContext: modelContext).finishSession(session, sessionRPE: rpe)
        WidgetSnapshotWriter.write(for: athlete, week: WeeklyPlan.generate(for: athlete))
        let sessionRef = session
        let sportSlug = athlete.activeSport?.sportSlug
        Task {
            // §17: one Apple Health workout per session, never a duplicate —
            // saveWorkout returns the existing id if one is already stored.
            let id = await HealthKitManager.shared.saveWorkout(
                start: sessionRef.startedAt, end: sessionRef.endedAt ?? .now,
                sportSlug: sportSlug, existingId: sessionRef.healthKitWorkoutId
            )
            if let id, sessionRef.healthKitWorkoutId == nil {
                sessionRef.healthKitWorkoutId = id
                sessionRef.syncedAt = nil
                try? modelContext.save()
            }
            await SyncQueue(apiClient: apiClient, tokenStore: KeychainTokenStore(), modelContext: modelContext).drainPendingSessions()
        }
        dismiss()
    }

    private func discard() {
        endActivity()
        if let session {
            modelContext.delete(session)
            try? modelContext.save()
        }
        dismiss()
    }

    private func setIdleTimerDisabled(_ disabled: Bool) {
        #if os(iOS) && !APP_EXTENSION
        UIApplication.shared.isIdleTimerDisabled = disabled
        #endif
    }
}

/// A huge minus / value / plus row — built for sweaty thumbs.
struct BigStepper: View {
    let label: String
    let value: String
    let onMinus: () -> Void
    let onPlus: () -> Void

    var body: some View {
        HStack {
            Button(action: onMinus) {
                Image(systemName: "minus")
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 60, height: 60)
                    .background(AppTheme.fill, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Decrease \(label.lowercased())")
            Spacer()
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 34, weight: .bold).monospacedDigit())
                    .foregroundStyle(AppTheme.ink)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
            Button(action: onPlus) {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.onAccent)
                    .frame(width: 60, height: 60)
                    .background(AppTheme.accent, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Increase \(label.lowercased())")
        }
        .cardStyle(padding: 14)
        .accessibilityElement(children: .contain)
        .accessibilityValue(value)
    }
}

/// Search the downloaded library and add an exercise to the session.
struct ExercisePickerSheet: View {
    let catalogue: Catalogue
    /// Whose drills may show (SportVisibility): never another sport's.
    let sports: [SportVisibility.Sport]
    let onPick: (CatalogueItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var group: QualityGroup?

    private var items: [CatalogueItem] {
        let filtered = catalogue.itemsBySlug.values
            .filter { (group == nil || $0.primaryQuality?.group == group) && SportVisibility.isVisible($0, sports: sports) }
            .sorted { $0.name < $1.name }
        return CatalogueSearch.rank(filtered, query: searchText)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ScreenTitle("Add exercise")
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(AppTheme.secondaryText)
                        TextField("Search", text: $searchText)
                    }
                    .padding(14)
                    .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button { group = nil } label: { Chip("All", isSelected: group == nil) }
                                .buttonStyle(.plain)
                            ForEach(QualityGroup.allCases, id: \.self) { value in
                                Button { group = value } label: { Chip(value.displayName, isSelected: group == value) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                    ForEach(items) { item in
                        Button {
                            onPick(item)
                            dismiss()
                        } label: {
                            LibraryRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .appScreen()
            .toolbar {
                CloseToolbarItem { dismiss() }
            }
        }
    }
}

/// §11: "After every training session, exactly one more question: how hard
/// was that, 1–10?"
struct RPEPromptView: View {
    @Binding var rpe: Int
    var heartRate: HeartRateSummary? = nil
    let onDone: () -> Void

    private func description(_ value: Int) -> String {
        switch value {
        case 1...2: "Very easy — could chat the whole time"
        case 3...4: "Easy — breathing a little harder"
        case 5...6: "Moderate — working, still in control"
        case 7...8: "Hard — only a few words at a time"
        case 9: "Very hard — nearly everything you had"
        default: "Maximum — nothing left"
        }
    }

    var body: some View {
        StepScaffold(title: "How hard was that?", subtitle: "1 = very easy, 10 = the hardest you could do. It tells us how to plan your next days.", buttonTitle: "Save session", onContinue: onDone) {
            VStack(spacing: 18) {
                if let heartRate {
                    Label("Heart rate \(heartRate.average) bpm on average, \(heartRate.max) at the top", systemImage: "heart.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.red)
                        .frame(maxWidth: .infinity)
                }
                Text("\(rpe)")
                    .font(.system(size: 80, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                    .contentTransition(.numericText())
                    .frame(maxWidth: .infinity)
                Text(description(rpe))
                    .font(.headline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                    ForEach(1...10, id: \.self) { value in
                        Button {
                            withAnimation(.snappy) { rpe = value }
                        } label: {
                            Text("\(value)")
                                .font(.headline)
                                .foregroundStyle(rpe == value ? AppTheme.onAccent : AppTheme.ink)
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .background(rpe == value ? AppTheme.accent : AppTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Effort \(value) of 10: \(description(value))")
                    }
                }
            }
        }
    }
}
