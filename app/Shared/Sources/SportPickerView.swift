import SwiftData
import SwiftUI

/// §15 onboarding steps 3–4 ("pick your sport, then position... season dates
/// with sensible defaults per sport, editable"), split out as its own
/// required gate rather than folded into OnboardingView's sign-in/download
/// flow. By the time an athlete reaches this they have an account and the
/// core pack; picking a sport is what turns the compiled-in plan generator
/// (M6/M7) into something real to look at, so it's required, not skippable —
/// §15 says the SPORT choice specifically is the one non-skippable step.
@MainActor
public struct SportPickerView: View {
    let athlete: Athlete
    @Environment(\.modelContext) private var modelContext
    @State private var selectedSport: SportInfo?
    @State private var seasonStart = Date.now
    @State private var seasonEnd = Date.now
    @State private var isSaving = false
    @State private var errorMessage: String?

    public init(athlete: Athlete) {
        self.athlete = athlete
    }

    public var body: some View {
        NavigationStack {
            Group {
                if let selectedSport {
                    seasonStep(for: selectedSport)
                } else {
                    sportListStep
                }
            }
            .background(AppBackground())
            .navigationTitle("Your sport")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var sportListStep: some View {
        List(allSports.sorted { $0.name < $1.name }, id: \.slug) { sport in
            Button {
                selectedSport = sport
                let defaults = Self.defaultSeasonDates(for: sport)
                seasonStart = defaults.start
                seasonEnd = defaults.end
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sport.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(Self.seasonLabel(sport.season))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func seasonStep(for sport: SportInfo) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(sport.name)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("When's your season?")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))

                VStack(spacing: 4) {
                    DatePicker("Season starts", selection: $seasonStart, displayedComponents: .date)
                    DatePicker("Season ends", selection: $seasonEnd, displayedComponents: .date)
                }
                .colorScheme(.dark)
                .cardStyle()

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }

                Button(isSaving ? "Setting up…" : "Continue") {
                    confirm(sport: sport)
                }
                .buttonStyle(.accentFilled)
                .disabled(isSaving)

                Button("Choose a different sport") { selectedSport = nil }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(24)
        }
    }

    private func confirm(sport: SportInfo) {
        isSaving = true
        errorMessage = nil
        Task {
            let client = APIClient(baseURL: AppConfig.backendBaseURL)
            let downloader = PackDownloader(client: client, packsDirectory: AppConfig.packsDirectory())
            // Offline-first (§3): the sport's own profile is already
            // compiled in (allSports), so the athlete can proceed even if
            // the drills/skills pack can't be fetched right now — a failed
            // download here is never fatal to finishing sport selection.
            if let manifest = try? await downloader.fetchManifest(),
               let entry = manifest.packs.first(where: { $0.slug == sport.slug }) {
                if (try? await downloader.download(slug: sport.slug, manifest: manifest)) != nil {
                    try? DownloadedPackRecorder(context: modelContext).record(slug: sport.slug, version: entry.version)
                }
            }
            save(sport: sport)
            isSaving = false
        }
    }

    private func save(sport: SportInfo) {
        let athleteSport = AthleteSport(
            sportSlug: sport.slug, seasonStart: seasonStart, seasonEnd: seasonEnd,
            isPrimary: true, athlete: athlete
        )
        modelContext.insert(athleteSport)
        try? modelContext.save()
    }

    /// WINTER-style sports (e.g. basketball: Nov–March) wrap into the
    /// following year — `monthRange`'s end month can be numerically less
    /// than its start month, which means "next year," not "invalid."
    static func defaultSeasonDates(for sport: SportInfo, calendar: Calendar = .current, now: Date = .now) -> (start: Date, end: Date) {
        let year = calendar.component(.year, from: now)
        let startMonth = sport.monthRange.first ?? 1
        let endMonth = sport.monthRange.count > 1 ? sport.monthRange[1] : startMonth
        let endYear = endMonth < startMonth ? year + 1 : year
        let start = calendar.date(from: DateComponents(year: year, month: startMonth, day: 1)) ?? now
        // day: 0 of (endMonth + 1) is the last day of endMonth.
        let end = calendar.date(from: DateComponents(year: endYear, month: endMonth + 1, day: 0)) ?? start
        return (start, end)
    }

    static func seasonLabel(_ season: String) -> String {
        season.capitalized.replacingOccurrences(of: "_", with: " ")
    }
}
