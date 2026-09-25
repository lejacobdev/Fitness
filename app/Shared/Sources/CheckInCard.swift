import SwiftData
import SwiftUI

/// §11's morning check-in: four questions, one tap each, and the fourth tap
/// saves — no separate Save button, which would break the fifteen-second
/// promise. Used inline on Today (fresh) and in a sheet to edit today's
/// answers (prefilled, every tap re-saves the same row per §14's
/// one-check-in-per-day rule).
struct CheckInCard: View {
    let athlete: Athlete
    var onSubmitted: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @State private var sleep: Int?
    @State private var soreness: Int?
    @State private var energy: Int?
    @State private var stress: Int?
    @State private var saveCount = 0
    /// §17: "hours slept pulled from HealthKit when available so they only
    /// confirm" — shown as a hint under the sleep question and saved with
    /// the check-in, never an extra tap.
    @State private var healthSleepHours: Double?
    /// Answers filled in from Apple Health (until the athlete changes them).
    @State private var sleepFromHealth = false
    @State private var energyFromHealth = false
    @State private var heartRate: (today: Double, usual: Double?)?
    @State private var canConnectHealth = false

    init(athlete: Athlete, existing: CheckIn? = nil, onSubmitted: @escaping () -> Void = {}) {
        self.athlete = athlete
        self.onSubmitted = onSubmitted
        _sleep = State(initialValue: existing?.sleepQuality)
        _soreness = State(initialValue: existing?.soreness)
        _energy = State(initialValue: existing?.energy)
        _stress = State(initialValue: existing?.stress)
    }

    private var answeredCount: Int {
        [sleep, soreness, energy, stress].compactMap { $0 }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Morning check-in")
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.ink)
                    Text(sleepFromHealth || energyFromHealth
                         ? "\(4 - answeredCount) taps left — Apple Health filled in the rest. It saves itself."
                         : "Four taps — it saves itself and tunes today's session to how you feel.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                RingView(progress: Double(answeredCount) / 4, color: AppTheme.ink, lineWidth: 5) {
                    Text("\(answeredCount)/4")
                        .font(.caption2.bold())
                        .foregroundStyle(AppTheme.ink)
                }
                .frame(width: 46, height: 46)
            }

            scaleRow("How did you sleep?", systemImage: "moon.fill", color: AppTheme.purple, low: "Poorly", high: "Great",
                     selection: Binding(get: { sleep }, set: { sleep = $0; sleepFromHealth = false }))
            if let healthSleepHours {
                Label(sleepFromHealth
                      ? "Filled in from Apple Health: \(SleepMath.label(healthSleepHours)) — tap to change"
                      : "Apple Health says \(SleepMath.label(healthSleepHours))", systemImage: "heart.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.purple)
                    .padding(.top, -10)
            }
            scaleRow("How sore are you?", systemImage: "figure.walk", color: AppTheme.orange, low: "Not at all", high: "Very sore", selection: $soreness)
            scaleRow("How is your energy?", systemImage: "bolt.fill", color: AppTheme.amber, low: "Drained", high: "Buzzing",
                     selection: Binding(get: { energy }, set: { energy = $0; energyFromHealth = false }))
            if energyFromHealth, let heartRate, let usual = heartRate.usual {
                Label("Filled in from your resting heart rate: \(Int(heartRate.today.rounded())) (usually \(Int(usual.rounded()))) — tap to change",
                      systemImage: "heart.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.amber)
                    .padding(.top, -10)
            }
            scaleRow("How is stress / school?", systemImage: "book.fill", color: AppTheme.blue, low: "Calm", high: "Stressed", selection: $stress)
            if canConnectHealth {
                Button {
                    Task {
                        await HealthKitManager.shared.requestAuthorization()
                        canConnectHealth = false
                        await prefillFromHealth()
                    }
                } label: {
                    Label("Let Apple Health fill in sleep and energy", systemImage: "heart.text.square.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .cardStyle()
        .sensoryFeedback(.success, trigger: saveCount)
        .task {
            canConnectHealth = await HealthKitManager.shared.needsAuthorization()
            await prefillFromHealth()
        }
        .onChange(of: sleep) { saveIfComplete() }
        .onChange(of: soreness) { saveIfComplete() }
        .onChange(of: energy) { saveIfComplete() }
        .onChange(of: stress) { saveIfComplete() }
    }

    private func scaleRow(
        _ title: String, systemImage: String, color: Color, low: String, high: String, selection: Binding<Int?>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 28, height: 28)
                    .background(color.opacity(0.14), in: Circle())
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
            }
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { value in
                    let isSelected = selection.wrappedValue == value
                    Button {
                        selection.wrappedValue = value
                    } label: {
                        Text("\(value)")
                            .font(.headline)
                            .foregroundStyle(isSelected ? AppTheme.onAccent : AppTheme.ink)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(isSelected ? AppTheme.accent : AppTheme.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title) \(value) of 5")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            HStack {
                Text(low)
                Spacer()
                Text(high)
            }
            .font(.caption2)
            .foregroundStyle(AppTheme.secondaryText)
        }
    }

    /// Sleep from the hours slept, energy from resting heart rate — only
    /// for questions not answered yet.
    private func prefillFromHealth() async {
        healthSleepHours = await HealthKitManager.shared.sleepHours()
        if sleep == nil, let hours = healthSleepHours {
            sleep = CheckInPrefill.sleepRating(hours: hours)
            sleepFromHealth = true
        }
        heartRate = await HealthKitManager.shared.restingHeartRate()
        if energy == nil, let heartRate, let rating = CheckInPrefill.energyRating(restingHeartRate: heartRate.today, usual: heartRate.usual) {
            energy = rating
            energyFromHealth = true
        }
    }

    private func saveIfComplete() {
        guard let sleep, let soreness, let energy, let stress else { return }
        _ = try? CheckInStore(modelContext: modelContext).submit(
            athlete: athlete, sleepQuality: sleep, sleepHours: healthSleepHours,
            soreness: soreness, energy: energy, stress: stress
        )
        saveCount += 1
        WidgetSnapshotWriter.write(for: athlete, week: WeeklyPlan.generate(for: athlete))
        onSubmitted()
    }
}

/// Edit today's check-in after the fact — the same four questions, prefilled.
struct CheckInSheet: View {
    let athlete: Athlete
    @Environment(\.dismiss) private var dismiss
    @State private var firstToday = true

    init(athlete: Athlete) {
        self.athlete = athlete
        _firstToday = State(initialValue: AthleteStats.todaysCheckIn(athlete) == nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // A first check-in closes itself once all four answers are in.
                    CheckInCard(athlete: athlete, existing: AthleteStats.todaysCheckIn(athlete)) {
                        if firstToday {
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(700))
                                dismiss()
                            }
                        }
                    }
                    if let band = AthleteStats.todaysCheckIn(athlete)?.readinessBand {
                        ReadinessSummaryRow(band: band)
                    }
                }
                .padding(20)
            }
            .appScreen()
            .navigationTitle("Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

struct ReadinessSummaryRow: View {
    let band: ReadinessBand

    private var text: String {
        switch band {
        case .green: "You're at or above your normal. Today's plan runs as generated."
        case .amber: "A little below your normal. Today's volume is trimmed about 20%."
        case .red: "Well below your normal. Today becomes movement, mobility and an early night."
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(AppTheme.color(for: band))
                .frame(width: 14, height: 14)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppTheme.ink)
            Spacer(minLength: 0)
        }
        .cardStyle(padding: 16)
    }
}
