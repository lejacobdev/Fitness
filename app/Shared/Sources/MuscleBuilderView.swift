import SwiftUI

/// "Pick the muscles you want to strengthen" → a complete, startable
/// workout. Body map on top, region chips to choose, a length, and the
/// generated session underneath — regenerate for a fresh variation.
struct MuscleBuilderView: View {
    let athlete: Athlete
    let apiClient: APIClient

    @State private var regions: Set<MuscleRegion> = []
    @State private var minutes = 40
    @State private var catalogue = Catalogue()
    @State private var workout: GeneratedSession?
    @State private var variation = 0
    @State private var detailItem: CatalogueItem?
    @State private var showingPaywall = false
    @State private var ledgerVersion = 0

    /// `nil` = unlimited (Pro).
    private var freeLeft: Int? {
        _ = ledgerVersion
        return ProGate.remainingMuscleWorkouts(isPro: ProAccess.isPro, startDates: MuscleWorkoutLedger.dates)
    }

    /// Friendly presets — the combinations athletes actually ask for.
    private let presets: [(title: String, regions: Set<MuscleRegion>)] = [
        ("Legs", [.quadriceps, .hamstrings, .hip, .calf]),
        ("Upper body", [.chest, .upperBack, .shoulder, .arm]),
        ("Core", [.trunk, .lowerBack]),
        ("Push", [.chest, .shoulder, .arm]),
        ("Pull", [.upperBack, .arm, .forearm]),
        ("Full body", [.quadriceps, .hamstrings, .chest, .upperBack, .trunk]),
    ]

    private var highlight: [String: Double] {
        var result: [String: Double] = [:]
        for muscle in muscles where regions.contains(muscle.region) {
            result[muscle.id] = 1
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                MuscleMapView(side: .front, weights: highlight)
                    .frame(height: 200)
                MuscleMapView(side: .back, weights: highlight)
                    .frame(height: 200)
            }
            .frame(maxWidth: .infinity)
            .cardStyle()
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 10) {
                Text("Quick picks")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(presets, id: \.title) { preset in
                            Button {
                                regions = preset.regions
                                rebuild()
                            } label: {
                                Chip(preset.title, isSelected: regions == preset.regions)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Muscles")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Spacer()
                    if !regions.isEmpty {
                        Button("Clear") {
                            regions = []
                            workout = nil
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                FlowLayout(spacing: 8) {
                    ForEach(MuscleRegion.allCases, id: \.self) { region in
                        Button {
                            if regions.contains(region) { regions.remove(region) } else { regions.insert(region) }
                            rebuild()
                        } label: {
                            Chip(region.coachName.capitalized, isSelected: regions.contains(region))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("How long?")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                HStack(spacing: 8) {
                    ForEach([20, 30, 40, 60], id: \.self) { value in
                        Button {
                            minutes = value
                            rebuild()
                        } label: {
                            Chip("\(value) min", isSelected: minutes == value)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let workout {
                workoutCard(workout)
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "hand.tap.fill")
                        .foregroundStyle(AppTheme.secondaryText)
                    Text("Pick one or more body areas and your workout builds itself.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle(padding: 16)
            }
        }
        .task { catalogue = CatalogueLoader.load(from: AppConfig.packsDirectory()) }
        .proPaywall(isPresented: $showingPaywall, athlete: athlete, feature: .muscleWorkouts)
        .sheet(item: $detailItem) { item in
            NavigationStack { ItemDetailView(item: item) }
        }
    }

    private func workoutCard(_ workout: GeneratedSession) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.title)
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.ink)
                    Text("\(workout.estimatedMinutes) min · \(workout.items.count) exercises")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Button {
                    variation += 1
                    rebuild()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 38, height: 38)
                        .background(AppTheme.fill, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Give me a different workout")
            }
            if workout.items.isEmpty {
                Text("Nothing in your downloaded library trains that with your equipment yet. Try another area, or add equipment in Me → Equipment.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            ForEach(workout.items, id: \.order) { item in
                let catalogueItem = catalogue.item(item.itemSlug)
                Button {
                    detailItem = catalogueItem
                } label: {
                    HStack(spacing: 12) {
                        ItemThumbnail(item: catalogueItem, size: 52)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(catalogueItem?.name ?? displayName(forSlug: item.itemSlug))
                                .font(.subheadline.bold())
                                .foregroundStyle(AppTheme.ink)
                                .multilineTextAlignment(.leading)
                            Text(DoseFormatter.text(item.dose))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.orange)
                            Text(item.rationale)
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)
                .disabled(catalogueItem == nil)
            }
            if !workout.items.isEmpty {
                VStack(spacing: 8) {
                    StartWorkoutButton(freeLeft == 0 ? "Start workout · Pro" : "Start workout", session: workout) {
                        if freeLeft == 0 {
                            showingPaywall = true
                            return false
                        }
                        if freeLeft != nil {
                            MuscleWorkoutLedger.record()
                            ledgerVersion += 1
                        }
                        return true
                    }
                    if let freeLeft {
                        Text(freeLeft == 0
                             ? "You've used this week's free muscle workout. Pro makes them unlimited — your weekly plan stays free."
                             : "\(freeLeft) free muscle workout left this week.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
        .cardStyle()
    }

    private func rebuild() {
        guard !regions.isEmpty else {
            workout = nil
            return
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            workout = MuscleWorkoutGenerator.generate(MuscleWorkoutInput(
                regions: regions, minutes: minutes, birthDate: athlete.birthDate,
                trainsUnderCoach: athlete.trainsUnderCoach, equipmentAvailable: Set(athlete.equipmentAvailable),
                catalogue: catalogue, seed: "\(athlete.id)-muscles-\(regions.map(\.rawValue).sorted().joined())-\(minutes)-\(variation)"
            ))
        }
    }
}
