import Observation
import SwiftData
import SwiftUI
import WatchKit

/// The Watch's live session: every set is written to the Watch's own
/// SwiftData store the moment it's logged (§16: "an app that silently loses
/// a logged set is worse than no Watch app"), then drained straight to the
/// backend with the same clientId idempotency as the phone.
@MainActor
@Observable
final class WatchSessionModel {
    enum Page: Hashable { case current, rest, list, metrics }

    let items: [WatchPlanItem]
    let workout = WorkoutManager()
    var index = 0
    var page: Page = .current
    var value: Double = 0
    var setsLogged: [Int]
    var restRemaining = 0
    var restTotal = 0
    var isFinishing = false
    var rpe: Double = 6
    let startedAt = Date()

    private var session: Session?
    private var restTask: Task<Void, Never>?

    init(items: [WatchPlanItem]) {
        self.items = items
        self.setsLogged = Array(repeating: 0, count: items.count)
        self.value = items.first?.targetValue ?? 8
    }

    var current: WatchPlanItem? { items.indices.contains(index) ? items[index] : nil }

    var totalSets: Int { max(items.reduce(0) { $0 + $1.sets }, 1) }
    var loggedSets: Int { setsLogged.reduce(0, +) }

    func start(athlete: Athlete, sportSlug: String, context: ModelContext) {
        guard session == nil else { return }
        session = try? SessionLogger(modelContext: context).startSession(athlete: athlete, source: .watch)
        workout.start(activity: WorkoutManager.activityType(forSport: sportSlug, hasSportDrills: items.contains { $0.isDrill }))
    }

    func jump(to position: Int) {
        guard items.indices.contains(position) else { return }
        index = position
        value = items[position].targetValue
        page = .current
    }

    func logSet(context: ModelContext) {
        guard let current, let session else { return }
        let setIndex = setsLogged[index]
        let amount = value
        _ = try? SessionLogger(modelContext: context).logSet(
            session: session, itemSlug: current.itemSlug, setIndex: setIndex,
            reps: current.doseKind == "reps" ? Int(amount) : nil,
            seconds: current.doseKind == "time" ? Int(amount) : nil,
            distanceM: current.doseKind == "distance" ? amount : nil,
            contacts: current.doseKind == "contacts" ? Int(amount) : nil
        )
        setsLogged[index] = setIndex + 1
        WKInterfaceDevice.current().play(.click)

        let finishedItem = setIndex + 1 >= current.sets
        let rest = current.restSec
        if finishedItem, index < items.count - 1 {
            index += 1
            value = items[index].targetValue
        }
        startRest(rest)
    }

    private func startRest(_ seconds: Int) {
        restTask?.cancel()
        restTotal = max(seconds, 1)
        restRemaining = seconds
        page = .rest
        restTask = Task { [weak self] in
            while let model = self, model.restRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                model.restRemaining -= 1
            }
            // §16: "distinct haptic at zero" — the notification pattern is
            // the one that is unmistakable on a moving wrist.
            WKInterfaceDevice.current().play(.notification)
            self?.page = .current
        }
    }

    func skipRest() {
        restTask?.cancel()
        restRemaining = 0
        page = .current
    }

    func finish(context: ModelContext, onDone: @escaping @MainActor () -> Void) {
        restTask?.cancel()
        guard let session else {
            onDone()
            return
        }
        if loggedSets == 0 {
            context.delete(session)
            try? context.save()
            workout.end { _ in onDone() }
            return
        }
        try? SessionLogger(modelContext: context).finishSession(session, sessionRPE: Int(rpe.rounded()))
        workout.end { workoutId in
            session.healthKitWorkoutId = workoutId
            try? context.save()
            WKInterfaceDevice.current().play(.success)
            onDone()
        }
    }
}

struct WatchSessionView: View {
    let items: [WatchPlanItem]
    let title: String
    let athlete: Athlete
    let sportSlug: String
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var model: WatchSessionModel

    init(items: [WatchPlanItem], title: String, athlete: Athlete, sportSlug: String, onClose: @escaping () -> Void) {
        self.items = items
        self.title = title
        self.athlete = athlete
        self.sportSlug = sportSlug
        self.onClose = onClose
        _model = State(initialValue: WatchSessionModel(items: items))
    }

    var body: some View {
        Group {
            if model.isFinishing {
                WatchRPEView(model: model) {
                    model.finish(context: modelContext) {
                        Task { await WatchSync.drain(context: modelContext) }
                        onClose()
                    }
                }
            } else {
                TabView(selection: $model.page) {
                    WatchCurrentItemPage(model: model).tag(WatchSessionModel.Page.current)
                    WatchRestPage(model: model).tag(WatchSessionModel.Page.rest)
                    WatchSessionListPage(model: model).tag(WatchSessionModel.Page.list)
                    WatchMetricsPage(model: model, onEnd: { model.isFinishing = true }).tag(WatchSessionModel.Page.metrics)
                }
                .tabViewStyle(.verticalPage)
            }
        }
        .onAppear { model.start(athlete: athlete, sportSlug: sportSlug, context: modelContext) }
    }
}

struct WatchCurrentItemPage: View {
    @Bindable var model: WatchSessionModel
    @Environment(\.modelContext) private var modelContext

    private var maxValue: Double {
        switch model.current?.doseKind {
        case "time": 600
        case "distance": 2000
        default: 100
        }
    }

    private var step: Double {
        switch model.current?.doseKind {
        case "time", "distance": 5
        default: 1
        }
    }

    var body: some View {
        if let current = model.current {
            VStack(spacing: 4) {
                Text(current.name)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text("Set \(min(model.setsLogged[model.index] + 1, current.sets)) of \(current.sets)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(Int(model.value))")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .focusable()
                    .digitalCrownRotation(
                        $model.value, from: 0, through: maxValue, by: step,
                        sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true
                    )
                    .accessibilityLabel("\(Int(model.value)) \(current.unitLabel)")
                Text(current.unitLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button {
                    model.logSet(context: modelContext)
                } label: {
                    Text("Log set")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
                Text("All done")
                    .font(.headline)
                Text("Scroll down to finish.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct WatchRestPage: View {
    @Bindable var model: WatchSessionModel

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(.white.opacity(0.15), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: model.restTotal > 0 ? Double(model.restRemaining) / Double(model.restTotal) : 0)
                    .stroke(.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: model.restRemaining)
                VStack(spacing: 0) {
                    Text(String(format: "%d:%02d", model.restRemaining / 60, model.restRemaining % 60))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(model.restRemaining > 0 ? "rest" : "go")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            if model.restRemaining > 0 {
                Button("Skip") { model.skipRest() }
                    .font(.footnote)
            }
        }
    }
}

struct WatchSessionListPage: View {
    @Bindable var model: WatchSessionModel

    var body: some View {
        List {
            ForEach(Array(model.items.enumerated()), id: \.offset) { position, item in
                Button {
                    model.jump(to: position)
                } label: {
                    HStack {
                        Image(systemName: model.setsLogged[position] >= item.sets ? "checkmark.circle.fill" : (position == model.index ? "play.circle.fill" : "circle"))
                            .foregroundStyle(model.setsLogged[position] >= item.sets ? .green : .white)
                        VStack(alignment: .leading) {
                            Text(item.name).font(.footnote).lineLimit(2)
                            Text("\(model.setsLogged[position])/\(item.sets) sets")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

struct WatchMetricsPage: View {
    @Bindable var model: WatchSessionModel
    let onEnd: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            TimelineView(.periodic(from: model.startedAt, by: 1)) { context in
                let elapsed = Int(context.date.timeIntervalSince(model.startedAt))
                Text(String(format: "%d:%02d", elapsed / 60, elapsed % 60))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            HStack(spacing: 4) {
                Image(systemName: "heart.fill").foregroundStyle(.red)
                Text(model.workout.heartRate > 0 ? "\(Int(model.workout.heartRate)) bpm" : "-- bpm")
                    .font(.headline)
            }
            Text("\(model.loggedSets)/\(model.totalSets) sets · \(Int(model.workout.activeEnergy)) kcal")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Button(role: .destructive, action: onEnd) {
                Text("End session").frame(maxWidth: .infinity)
            }
        }
    }
}

/// §15/§11: the session ends with the single RPE question and nothing else.
struct WatchRPEView: View {
    @Bindable var model: WatchSessionModel
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Text("How hard was that?")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("\(Int(model.rpe.rounded()))")
                .font(.system(size: 54, weight: .bold, design: .rounded))
                .focusable()
                .digitalCrownRotation($model.rpe, from: 1, through: 10, by: 1, sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
            Text("1 easy · 10 max")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Button {
                onSave()
            } label: {
                Text(model.loggedSets == 0 ? "Close" : "Save").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(.black)
        }
    }
}
