import Charts
import SwiftUI
#if os(iOS)
import UIKit
#endif

/// "Tests": the same few tests every 6–8 weeks, and how much better the
/// athlete got since the last time.
struct BenchmarksView: View {
    let sportSlug: String?

    @Environment(\.dismiss) private var dismiss
    @State private var results = BenchmarkStore.results
    @State private var running: BenchmarkTest?
    @State private var detail: BenchmarkTest?

    private var tests: [BenchmarkTest] { BenchmarkCatalog.tests(for: sportSlug) }
    private var status: BenchmarkSchedule.Status { BenchmarkSchedule.status(lastTest: BenchmarkStore.lastTestDate(results)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle("Tests", subtitle: "Every 6–8 weeks, the same tests done the same way — so you can see how much faster, stronger and better you've become.")
                    statusCard
                    SectionHeader("Body", subtitle: "Power, speed, strength.")
                    ForEach(tests.filter { $0.level == .body }) { testRow($0) }
                    if let sportTest = tests.first(where: { $0.level == .sport }) {
                        SectionHeader("Your sport", subtitle: "One test of a skill that matters in your sport.")
                        testRow(sportTest)
                    }
                    Text("Test on a fresh day — not after a hard workout or a game — after a proper warm-up.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .containerRelativeFrame(.horizontal)
            }
            .scrollIndicators(.hidden)
            .appScreen()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
            .sheet(item: $running, onDismiss: { results = BenchmarkStore.results }) { test in
                BenchmarkRunView(test: test)
            }
            .sheet(item: $detail, onDismiss: { results = BenchmarkStore.results }) { test in
                BenchmarkHistoryView(test: test)
            }
        }
    }

    private var statusCard: some View {
        let (title, text, color): (String, String, Color) = {
            switch status {
            case .firstTime: return ("Your first tests", "These results are your starting point. In 6 weeks you test again and see what changed.", AppTheme.accent)
            case .notYet(let days): return ("Next tests in \(days) days", "Keep training — you'll see the difference.", AppTheme.green)
            case .due: return ("Test week", "It's been 6 weeks: time to see how much you've improved.", AppTheme.accent)
            case .overdue: return ("Tests are overdue", "It's been over 8 weeks. Test this week to keep your progress honest.", AppTheme.red)
            }
        }()
        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if let headline = BenchmarkMath.headline(results, tests: tests) {
                Label(headline, systemImage: "arrow.up.right.circle.fill")
                    .font(.headline)
                    .foregroundStyle(AppTheme.green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func testRow(_ test: BenchmarkTest) -> some View {
        let change = BenchmarkMath.change(results, test: test)
        return HStack(spacing: 14) {
            Button { detail = test } label: {
                HStack(spacing: 14) {
                    Image(systemName: test.systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.brand)
                        .frame(width: 48, height: 48)
                        .background(AppTheme.brand.opacity(0.12), in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(test.name)
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                        if let change {
                            Text(test.unit.format(change.latest.value))
                                .font(.title3.bold())
                                .foregroundStyle(AppTheme.ink)
                            if let delta = change.delta, let improved = change.improved {
                                Text(test.unit.formatChange(delta, higherIsBetter: test.higherIsBetter) + " than last time")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(improved ? AppTheme.green : AppTheme.secondaryText)
                            }
                        } else {
                            Text("Not tested yet")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            Button { running = test } label: {
                Text("Test")
                    .font(.headline)
                    .foregroundStyle(AppTheme.onAccent)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)
                    .background(AppTheme.accent, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .cardStyle(padding: 14)
    }
}

// MARK: - One test's history

struct BenchmarkHistoryView: View {
    let test: BenchmarkTest

    @Environment(\.dismiss) private var dismiss
    @State private var results: [BenchmarkResult] = []
    @State private var pendingDelete: BenchmarkResult?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle(test.name, subtitle: test.higherIsBetter ? "Higher is better." : "Lower is better.")
                    if results.count >= 2 {
                        Chart(results) { result in
                            LineMark(x: .value("Date", result.date), y: .value(test.name, result.value))
                                .foregroundStyle(AppTheme.accent)
                            PointMark(x: .value("Date", result.date), y: .value(test.name, result.value))
                                .foregroundStyle(AppTheme.accent)
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 200)
                        .cardStyle()
                    }
                    if let best = BenchmarkMath.best(results, test: test) {
                        Label("Best: \(test.unit.format(best.value)) on \(best.date.formatted(date: .abbreviated, time: .omitted))", systemImage: "trophy.fill")
                            .font(.headline)
                            .foregroundStyle(AppTheme.amber)
                    }
                    VStack(spacing: 0) {
                        ForEach(results.reversed()) { result in
                            HStack {
                                Text(result.date.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundStyle(AppTheme.secondaryText)
                                Spacer()
                                Text(test.unit.format(result.value))
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.ink)
                                Button { pendingDelete = result } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(AppTheme.secondaryText)
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Delete this result")
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .cardStyle(padding: 14)
                    SectionHeader("How to do it")
                    HowToSteps(steps: test.howTo)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .containerRelativeFrame(.horizontal)
            }
            .appScreen()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
            .task { results = BenchmarkStore.results.filter { $0.testID == test.id } }
            .confirmationDialog("Delete this result?", isPresented: Binding(
                get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }
            ), titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let result = pendingDelete { BenchmarkStore.delete(result) }
                    results = BenchmarkStore.results.filter { $0.testID == test.id }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            }
        }
    }
}

/// Numbered how-to steps, big and plain.
struct HowToSteps: View {
    let steps: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.subheadline.bold())
                        .foregroundStyle(AppTheme.onAccent)
                        .frame(width: 28, height: 28)
                        .background(AppTheme.accent, in: Circle())
                    Text(step)
                        .font(.body)
                        .foregroundStyle(AppTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 16)
    }
}

// MARK: - Doing a test

/// How-to first, then the right tool: camera, stopwatch, counter or typing it in.
struct BenchmarkRunView: View {
    let test: BenchmarkTest

    @Environment(\.dismiss) private var dismiss
    @State private var typing = false
    @State private var typed = ""
    @State private var saved: Double?
    /// The test the saved result belongs to (the sprint saves 10 m and 30 m).
    @State private var savedTest: BenchmarkTest?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle(test.name, subtitle: test.higherIsBetter ? "Do your best — higher is better." : "Do your best — faster is better.")
                    if let saved {
                        savedCard(saved, test: savedTest ?? test)
                    } else {
                        HowToSteps(steps: test.howTo)
                        if typing || test.runner == .entry {
                            entry
                        } else {
                            tool
                            Button("I measured it another way — type it in") { typing = true }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .containerRelativeFrame(.horizontal)
            }
            .appScreen()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(saved == nil ? "Cancel" : "Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var tool: some View {
        switch test.runner {
        case .jumpVideo:
            #if os(iOS) && !APP_EXTENSION
            if ProAccess.isPro {
                JumpVideoTest { centimeters in save(centimeters) }
            } else {
                // Free: type the result in; the camera measurement is Pro.
                ProLockCard(feature: .videoJumpTest, title: "Measure it with the camera",
                            message: "Film your jump in slow motion and the app works out your height from the flight time. Or type in a result you measured another way.")
                entry
            }
            #else
            entry
            #endif
        case .sprintStopwatch:
            SprintStopwatch { tenMetres, thirtyMetres in
                if let tenMetres { BenchmarkStore.record(tenMetres, for: BenchmarkCatalog.sprint10) }
                save(thirtyMetres, as: BenchmarkCatalog.sprint30)
            }
        case .stopwatch:
            TestStopwatch { seconds in save(seconds) }
        case .counter:
            TestCounter(maximum: test.unit == .outOf10 ? 10 : nil, timeLimit: test.timeLimit) { count in save(Double(count)) }
        case .entry:
            entry
        }
    }

    private var unitLabel: String {
        switch test.unit {
        case .centimeters: "cm"
        case .seconds: "seconds"
        case .reps: "reps"
        case .outOf10: "out of 10"
        }
    }

    private var entry: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your result (\(unitLabel))")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)
            TextField(unitLabel, text: $typed)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                .font(.system(size: 34, weight: .bold))
                .padding(16)
                .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            if test.unit == .seconds {
                Text("For longer runs you can type minutes and seconds, like 6:12.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Button("Save") {
                if let value = Self.parse(typed, unit: test.unit) { save(value) }
            }
            .buttonStyle(.primary)
            .disabled(Self.parse(typed, unit: test.unit) == nil)
        }
    }

    /// "33", "4,52", "6:12" (minutes:seconds).
    nonisolated static func parse(_ text: String, unit: BenchmarkUnit) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        if unit == .seconds, cleaned.contains(":") {
            let parts = cleaned.split(separator: ":")
            guard parts.count == 2, let minutes = Double(parts[0]), let seconds = Double(parts[1]), seconds < 60 else { return nil }
            return minutes * 60 + seconds
        }
        guard let value = Double(cleaned), value > 0 else { return nil }
        if unit == .outOf10, value > 10 { return nil }
        return value
    }

    private func save(_ value: Double, as target: BenchmarkTest? = nil) {
        BenchmarkStore.record(value, for: target ?? test)
        savedTest = target ?? test
        saved = value
    }

    private func savedCard(_ value: Double, test: BenchmarkTest) -> some View {
        let change = BenchmarkMath.change(BenchmarkStore.results, test: test)
        return VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.green)
            Text(test.name)
                .font(.headline)
                .foregroundStyle(AppTheme.secondaryText)
            Text(test.unit.format(value))
                .font(.system(size: 48, weight: .heavy))
                .foregroundStyle(AppTheme.ink)
            if let delta = change?.delta, let improved = change?.improved {
                Text(test.unit.formatChange(delta, higherIsBetter: test.higherIsBetter) + " than last time")
                    .font(.title3.bold())
                    .foregroundStyle(improved ? AppTheme.green : AppTheme.secondaryText)
                if !improved {
                    Text("Tests go up and down — sleep, food and tiredness all count. Look at the trend over months, not one day.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
            } else {
                Text("Saved. This is your starting point.")
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.ink)
            }
            Button("Done") { dismiss() }
                .buttonStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}

// MARK: - Tools

/// A partner's stopwatch for the sprint: Go, 10 m, Stop.
struct SprintStopwatch: View {
    let onDone: (_ tenMetres: Double?, _ thirtyMetres: Double) -> Void

    @State private var startedAt: Date?
    @State private var split: Double?
    @State private var finished: Double?

    var body: some View {
        VStack(spacing: 16) {
            TimelineView(.animation(minimumInterval: 0.02, paused: startedAt == nil || finished != nil)) { context in
                let elapsed = finished ?? startedAt.map { context.date.timeIntervalSince($0) } ?? 0
                Text(String(format: "%.2f s", elapsed))
                    .font(.system(size: 60, weight: .heavy).monospacedDigit())
                    .foregroundStyle(AppTheme.ink)
                    .frame(maxWidth: .infinity)
            }
            if let split {
                Text(String(format: "10 m: %.2f s", split))
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.secondaryText)
            }
            if let finished {
                Button("Save") { onDone(split, finished) }
                    .buttonStyle(.primary)
                Button("Run again") { reset() }
                    .buttonStyle(.secondary)
            } else if let startedAt {
                if split == nil {
                    bigButton("10 m", color: AppTheme.orange) { split = Date.now.timeIntervalSince(startedAt) }
                }
                bigButton("Stop at 30 m", color: AppTheme.red) { finished = Date.now.timeIntervalSince(startedAt) }
            } else {
                bigButton("Go", color: AppTheme.green) { startedAt = .now }
            }
        }
        .cardStyle()
    }

    private func reset() {
        startedAt = nil
        split = nil
        finished = nil
    }
}

/// A stopwatch: start, stop, save.
struct TestStopwatch: View {
    let onDone: (Double) -> Void

    @State private var startedAt: Date?
    @State private var finished: Double?

    var body: some View {
        VStack(spacing: 16) {
            TimelineView(.animation(minimumInterval: 0.05, paused: startedAt == nil || finished != nil)) { context in
                let elapsed = finished ?? startedAt.map { context.date.timeIntervalSince($0) } ?? 0
                Text(elapsed >= 100 ? BenchmarkUnit.seconds.format(elapsed) : String(format: "%.1f s", elapsed))
                    .font(.system(size: 60, weight: .heavy).monospacedDigit())
                    .foregroundStyle(AppTheme.ink)
                    .frame(maxWidth: .infinity)
            }
            if let finished {
                Button("Save") { onDone((finished * 100).rounded() / 100) }
                    .buttonStyle(.primary)
                Button("Start over") { startedAt = nil; self.finished = nil }
                    .buttonStyle(.secondary)
            } else if let startedAt {
                bigButton("Stop", color: AppTheme.red) { finished = Date.now.timeIntervalSince(startedAt) }
            } else {
                bigButton("Start", color: AppTheme.green) { startedAt = .now }
            }
        }
        .cardStyle()
    }
}

/// A huge tap counter, with an optional countdown for "in 60 s" tests.
struct TestCounter: View {
    let maximum: Int?
    let timeLimit: Int?
    let onDone: (Int) -> Void

    @State private var count = 0
    @State private var timerStart: Date?
    @State private var timeUp = false

    var body: some View {
        VStack(spacing: 16) {
            if let timeLimit {
                TimelineView(.periodic(from: .now, by: 0.2)) { context in
                    let left = timerStart.map { max(0, Double(timeLimit) - context.date.timeIntervalSince($0)) } ?? Double(timeLimit)
                    Text(timeUp ? "Time!" : "\(Int(left.rounded(.up))) s")
                        .font(.title.bold().monospacedDigit())
                        .foregroundStyle(timeUp ? AppTheme.red : AppTheme.secondaryText)
                }
                if timerStart == nil {
                    Button { timerStart = .now } label: { Label("Start the \(timeLimit) s timer", systemImage: "timer") }
                        .buttonStyle(.secondary)
                }
            }
            Button {
                guard !timeUp, maximum.map({ count < $0 }) ?? true else { return }
                count += 1
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
            } label: {
                Text("\(count)")
                    .font(.system(size: 80, weight: .heavy).monospacedDigit())
                    .foregroundStyle(AppTheme.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .background(timeUp ? AppTheme.secondaryText : AppTheme.accent, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Count: \(count). Tap to add one.")
            ButtonRow {
                Button { count = max(0, count - 1) } label: { Label("One less", systemImage: "minus") }
                    .buttonStyle(.secondary)
                Button("Save") { onDone(count) }
                    .buttonStyle(.primary)
            }
        }
        .task(id: timerStart) {
            guard let timerStart, let timeLimit else { return }
            let wait = Double(timeLimit) - Date.now.timeIntervalSince(timerStart)
            try? await Task.sleep(nanoseconds: UInt64(max(0, wait) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            timeUp = true
            #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
        }
        .cardStyle()
    }
}

/// The big round start/stop buttons.
@MainActor
private func bigButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .font(.title.bold())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 88)
            .background(color, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
    .buttonStyle(.plain)
}
