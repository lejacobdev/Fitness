import SwiftData
import SwiftUI

/// M5: "Start a session, log sets and drills, finish, RPE, history." Before
/// M6 (plan generation) exists there is no prescribed "today's session" to
/// walk through, so this is a free-logging flow — pick an item from the
/// downloaded catalogue, log sets against it, repeat, finish. §15's fuller
/// "current item, prefilled targets, next/previous" live-session screen is
/// the plan-driven version of this, built once M6 gives it a plan to follow.
@MainActor
public struct LiveSessionView: View {
    let athlete: Athlete
    let apiClient: APIClient

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var session: Session?
    @State private var catalogue = Catalogue()
    @State private var selectedItem: CatalogueItem?
    @State private var nextSetIndexByItem: [String: Int] = [:]
    @State private var restSecondsRemaining: Int?
    @State private var showingFinishPrompt = false
    @State private var rpe = 5

    @State private var reps = 8
    @State private var weightKg: Double = 0
    @State private var seconds = 20
    @State private var distanceM: Double = 0
    @State private var contacts = 10

    public init(athlete: Athlete, apiClient: APIClient) {
        self.athlete = athlete
        self.apiClient = apiClient
    }

    public var body: some View {
        NavigationStack {
            Group {
                if let selectedItem {
                    logSetView(for: selectedItem)
                } else {
                    itemPickerView
                }
            }
            .padding()
            .navigationTitle("Training session")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") { showingFinishPrompt = true }
                }
            }
            .task {
                catalogue = CatalogueLoader.load(from: AppConfig.packsDirectory())
                if session == nil {
                    session = try? SessionLogger(modelContext: modelContext).startSession(athlete: athlete)
                }
            }
            .sheet(isPresented: $showingFinishPrompt) {
                RPEPromptView(rpe: $rpe, onDone: { finish() })
            }
        }
    }

    private var itemPickerView: some View {
        List(catalogue.itemsBySlug.values.sorted { $0.name < $1.name }, id: \.slug) { item in
            Button {
                selectedItem = item
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).font(.headline)
                    Text("\(item.kind.capitalized) · \(item.equipment.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .overlay {
            if catalogue.itemsBySlug.isEmpty {
                ContentUnavailableView(
                    "No items downloaded yet", systemImage: "shippingbox",
                    description: Text("Finish downloading a sport pack from onboarding first.")
                )
            }
        }
    }

    private func logSetView(for item: CatalogueItem) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(item.name).font(.title2.bold())
                if let firstCue = item.cues.first {
                    Text(firstCue)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                doseControls(for: item)

                if let restSecondsRemaining {
                    Text("Rest: \(restSecondsRemaining)s")
                        .font(.title.monospacedDigit())
                        .foregroundStyle(.orange)
                }

                Button("Log set") { logSet(item: item) }
                    .buttonStyle(.borderedProminent)
                    .font(.title3)

                Button("Choose a different item") { selectedItem = nil }
                    .buttonStyle(.bordered)
            }
            .padding()
        }
    }

    @ViewBuilder
    private func doseControls(for item: CatalogueItem) -> some View {
        switch item.defaultDose.kind {
        case "reps":
            Stepper("Reps: \(reps)", value: $reps, in: 1...50)
            Stepper("Weight: \(weightKg, specifier: "%.1f") kg", value: $weightKg, in: 0...300, step: 2.5)
        case "time":
            Stepper("Seconds: \(seconds)", value: $seconds, in: 1...600, step: 5)
        case "distance":
            Stepper("Distance: \(distanceM, specifier: "%.0f") m", value: $distanceM, in: 1...1000, step: 5)
        case "contacts":
            Stepper("Contacts: \(contacts)", value: $contacts, in: 1...100)
        default:
            EmptyView()
        }
    }

    private func logSet(item: CatalogueItem) {
        guard let session else { return }
        let setIndex = nextSetIndexByItem[item.slug, default: 0]
        _ = try? SessionLogger(modelContext: modelContext).logSet(
            session: session, itemSlug: item.slug, setIndex: setIndex,
            reps: item.defaultDose.kind == "reps" ? reps : nil,
            weightKg: (item.defaultDose.kind == "reps" && weightKg > 0) ? weightKg : nil,
            seconds: item.defaultDose.kind == "time" ? seconds : nil,
            distanceM: item.defaultDose.kind == "distance" ? distanceM : nil,
            contacts: item.defaultDose.kind == "contacts" ? contacts : nil
        )
        nextSetIndexByItem[item.slug] = setIndex + 1
        startRestTimer(seconds: item.restSeconds)
    }

    private func startRestTimer(seconds restDuration: Int) {
        restSecondsRemaining = restDuration
        Task {
            var remaining = restDuration
            while remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                remaining -= 1
                restSecondsRemaining = remaining > 0 ? remaining : nil
            }
        }
    }

    private func finish() {
        guard let session else { return }
        try? SessionLogger(modelContext: modelContext).finishSession(session, sessionRPE: rpe)
        Task {
            await SyncQueue(
                apiClient: apiClient, tokenStore: KeychainTokenStore(), modelContext: modelContext
            ).drainPendingSessions()
            dismiss()
        }
    }
}

/// §15: "It ends with the single RPE question and nothing else."
private struct RPEPromptView: View {
    @Binding var rpe: Int
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("How hard was that?").font(.title2.bold())
                Text("1 = very easy, 10 = maximum effort")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("RPE", selection: $rpe) {
                    ForEach(1...10, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                Button("Done") {
                    onDone()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}
