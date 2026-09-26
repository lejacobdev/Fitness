import SwiftData
import SwiftUI
import WatchKit

/// §16: the morning check-in on the wrist. With a watch that measured the
/// night, it's two taps: sleep and energy come from Apple Health, the
/// athlete answers soreness and pain. Without that data it's the four
/// questions. Saved through the same CheckInStore the phone uses.
struct WatchCheckInView: View {
    let athlete: Athlete
    let onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var step = 0
    @State private var answers: [Int] = []
    /// Sleep (hours, quality) and energy from Health; nil until loaded or when missing.
    @State private var measured: (hours: Double, sleep: Int, energy: Int)?
    @State private var loaded = false
    @State private var soreness: Int?

    private let questions: [(title: String, low: String, high: String)] = [
        ("How did you sleep?", "Poorly", "Great"),
        ("How sore are you?", "Not at all", "Very"),
        ("Your energy?", "Drained", "Buzzing"),
        ("Stress / school?", "Calm", "Stressed"),
    ]

    var body: some View {
        Group {
            if !loaded {
                ProgressView()
            } else if let measured {
                twoTaps(measured)
            } else {
                fourQuestions
            }
        }
        .task { await load() }
    }

    // MARK: - Two taps

    @ViewBuilder
    private func twoTaps(_ measured: (hours: Double, sleep: Int, energy: Int)) -> some View {
        VStack(spacing: 6) {
            Text("\(measured.hours.formatted(.number.precision(.fractionLength(1)))) h sleep")
                .font(.caption2)
                .foregroundStyle(.secondary)
            if soreness == nil {
                Text("How sore are you?").font(.headline)
                choices([("None", 1), ("Mild", 2), ("Some", 3), ("Very", 5)]) { soreness = $0; WKInterfaceDevice.current().play(.click) }
            } else {
                Text("Any pain?").font(.headline)
                choices([("No", 0), ("Yes", 1)]) { save(measured, pain: $0 == 1) }
            }
        }
    }

    private func choices(_ options: [(String, Int)], action: @escaping (Int) -> Void) -> some View {
        VStack(spacing: 4) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                Button { action(option.1) } label: {
                    Text(option.0).font(.system(size: 16, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.plain)
                .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private func save(_ measured: (hours: Double, sleep: Int, energy: Int), pain: Bool) {
        let yesterday = athlete.checkIns.max { $0.date < $1.date }
        _ = try? CheckInStore(modelContext: modelContext).submit(
            athlete: athlete, sleepQuality: measured.sleep, sleepHours: measured.hours, soreness: soreness ?? 2,
            energy: measured.energy, stress: yesterday?.stress ?? 2
        )
        if pain {
            // Where it hurts is asked on the phone; the plan eases off now.
            PhoneWatchBridge.shared.sendToPhone(day: DayKey.of(.now), pain: true)
        }
        WKInterfaceDevice.current().play(.success)
        onDone()
    }

    private func load() async {
        guard !loaded else { return }
        let health = HealthKitManager.shared
        if let hours = await health.sleepHours() {
            let energy = WearablePrefill.energy(restingHeartRate: await health.restingHeartRate(), hrv: await health.heartRateVariability())
            if let energy { measured = (hours, WearablePrefill.sleepQuality(hours: hours), energy) }
        }
        loaded = true
    }

    // MARK: - Four questions

    private var fourQuestions: some View {
        VStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? Color.white : Color.white.opacity(0.2))
                        .frame(height: 3)
                }
            }
            Text(questions[step].title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        answer(value)
                    } label: {
                        Text("\(value)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(.plain)
                    .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityLabel("\(questions[step].title) \(value) of 5")
                }
            }
            HStack {
                Text(questions[step].low)
                Spacer()
                Text(questions[step].high)
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
    }

    private func answer(_ value: Int) {
        answers.append(value)
        WKInterfaceDevice.current().play(.click)
        if answers.count == 4 {
            _ = try? CheckInStore(modelContext: modelContext).submit(
                athlete: athlete, sleepQuality: answers[0], soreness: answers[1], energy: answers[2], stress: answers[3]
            )
            WKInterfaceDevice.current().play(.success)
            onDone()
        } else {
            step += 1
        }
    }
}

/// The evening reflection on the wrist: two taps, sent to the phone.
struct WatchReflectionView: View {
    let onDone: () -> Void
    @State private var hardness: Int?

    var body: some View {
        VStack(spacing: 6) {
            if hardness == nil {
                Text("How hard was today?").font(.headline).multilineTextAlignment(.center)
                options([("Easy", 1), ("Okay", 2), ("Hard", 3), ("Very hard", 4)]) { hardness = $0; WKInterfaceDevice.current().play(.click) }
            } else {
                Text("How does your body feel?").font(.headline).multilineTextAlignment(.center)
                options([("Fresh", 1), ("Okay", 2), ("Sore", 3), ("Beaten up", 4)]) { body in
                    let day = DayKey.of(.now)
                    MindsetStore.saveEvening(hardness: hardness, body: body, practice: nil, wentWell: [], needsWork: [], learned: nil)
                    PhoneWatchBridge.shared.sendToPhone(day: day, hardness: hardness, body: body)
                    WKInterfaceDevice.current().play(.success)
                    onDone()
                }
            }
        }
    }

    private func options(_ values: [(String, Int)], action: @escaping (Int) -> Void) -> some View {
        VStack(spacing: 4) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                Button { action(value.1) } label: {
                    Text(value.0).font(.system(size: 16, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.plain)
                .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
}
