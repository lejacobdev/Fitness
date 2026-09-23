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
                    Text("Four taps — it saves itself and tunes today's session to how you feel.")
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

            scaleRow("How did you sleep?", systemImage: "moon.fill", color: AppTheme.purple, low: "Poorly", high: "Great", selection: $sleep)
            if let healthSleepHours {
                Label("Apple Health says \(SleepMath.label(healthSleepHours))", systemImage: "heart.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.purple)
                    .padding(.top, -10)
            }
            scaleRow("How sore are you?", systemImage: "figure.walk", color: AppTheme.orange, low: "Not at all", high: "Very sore", selection: $soreness)
            scaleRow("How is your energy?", systemImage: "bolt.fill", color: AppTheme.amber, low: "Drained", high: "Buzzing", selection: $energy)
            scaleRow("How is stress / school?", systemImage: "book.fill", color: AppTheme.blue, low: "Calm", high: "Stressed", selection: $stress)
        }
        .cardStyle()
        .sensoryFeedback(.success, trigger: saveCount)
        .task { healthSleepHours = await HealthKitManager.shared.sleepHours() }
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
                            .foregroundStyle(isSelected ? AppTheme.inkInverse : AppTheme.ink)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(isSelected ? AppTheme.ink : AppTheme.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    CheckInCard(athlete: athlete, existing: AthleteStats.todaysCheckIn(athlete))
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
