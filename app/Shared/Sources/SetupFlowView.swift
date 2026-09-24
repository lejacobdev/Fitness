import SwiftData
import SwiftUI

/// §15 onboarding after sign-in: "pick your sport, then position → season
/// dates (with sensible defaults per sport, editable) → equipment you
/// actually have access to → do you train under a coach → downloads your
/// sport pack." Only the sport choice is required; everything else has a
/// sensible default and a Skip.
@MainActor
public struct SetupFlowView: View {
    let athlete: Athlete
    @Environment(\.modelContext) private var modelContext

    private enum Step: Int, CaseIterable {
        case sport, position, season, equipment, coach, finishing
    }

    @State private var step: Step = .sport
    @State private var sportSlug: String?
    @State private var positionSlug: String?
    @State private var seasonStart = Date.now
    @State private var seasonEnd = Date.now
    @State private var equipment: Set<String> = []
    @State private var trainsUnderCoach: Bool?
    @State private var finishingMessage = "Building your plan…"

    public init(athlete: Athlete) {
        self.athlete = athlete
    }

    private var sport: SportInfo? { sportSlug.flatMap { allSportsBySlug[$0] } }

    private var progress: Double {
        Double(step.rawValue + 1) / Double(Step.allCases.count)
    }

    public var body: some View {
        Group {
            switch step {
            case .sport:
                StepScaffold(
                    progress: progress, title: "What's your sport?", subtitle: "Your whole plan is built around it. Play more than one? You can add the others later in Me → Sports.",
                    buttonEnabled: sportSlug != nil, onContinue: chooseSport
                ) {
                    SportChooser(selection: $sportSlug)
                }
            case .position:
                StepScaffold(
                    progress: progress, title: "What position do you play?", subtitle: "Positions lean on different qualities — a goalkeeper isn't a midfielder.",
                    onBack: { go(.sport) }, onContinue: { go(.season) }
                ) {
                    if let sport {
                        PositionChooser(sport: sport, selection: $positionSlug)
                    }
                }
            case .season:
                StepScaffold(
                    progress: progress, title: "When's your season?", subtitle: "We filled in the usual dates for \(sport?.name ?? "your sport"). Adjust them to your team's.",
                    onBack: { go(sport?.positions.isEmpty == false ? .position : .sport) }, onContinue: { go(.equipment) }
                ) {
                    SeasonEditor(start: $seasonStart, end: $seasonEnd)
                }
            case .equipment:
                StepScaffold(
                    progress: progress, title: "What can you train with?", subtitle: "Only pick what you actually have access to. Nothing is fine too.",
                    onBack: { go(.season) }, onContinue: { go(.coach) }
                ) {
                    EquipmentChooser(selection: $equipment)
                }
            case .coach:
                StepScaffold(
                    progress: progress, title: "Do you train under a coach?", subtitle: "A coach, trainer or PE teacher who watches you lift. Say no and we only give you moves that are safe to learn alone — you can change it later in Me.",
                    buttonTitle: "Finish setup", buttonEnabled: trainsUnderCoach != nil,
                    onBack: { go(.equipment) }, onContinue: finish
                ) {
                    CoachChooser(selection: $trainsUnderCoach)
                }
            case .finishing:
                finishingView
            }
        }
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    private var finishingView: some View {
        VStack(spacing: 22) {
            Spacer()
            RingView(progress: 0.75, color: AppTheme.ink, lineWidth: 10) {
                Image(systemName: sportSlug.map(SportIcon.name(for:)) ?? "sportscourt.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(AppTheme.ink)
            }
            .frame(width: 130, height: 130)
            Text(finishingMessage)
                .font(.title2.bold())
                .foregroundStyle(AppTheme.ink)
            Text("Downloading your \(sport?.name ?? "sport") library and generating this week.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            ProgressView()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .appScreen()
    }

    private func go(_ next: Step) {
        step = next
    }

    private func chooseSport() {
        guard let sport else { return }
        let defaults = SeasonDefaults.dates(for: sport)
        seasonStart = defaults.start
        seasonEnd = defaults.end
        positionSlug = nil
        go(sport.positions.isEmpty ? .season : .position)
    }

    private func finish() {
        guard let sport else { return }
        go(.finishing)
        Task {
            await SportPackInstaller.install(slug: sport.slug, context: modelContext)
            athlete.equipmentAvailable = Array(equipment).sorted()
            athlete.trainsUnderCoach = trainsUnderCoach ?? false
            modelContext.insert(AthleteSport(
                sportSlug: sport.slug, positionSlug: positionSlug,
                seasonStart: seasonStart, seasonEnd: seasonEnd, isPrimary: true, athlete: athlete
            ))
            try? modelContext.save()
        }
    }
}

/// Downloads one sport's pack if it can. §3 offline-first: the sport's
/// profile is compiled in, so a failed download never blocks anything.
@MainActor
enum SportPackInstaller {
    static func install(slug: String, context: ModelContext) async {
        let client = APIClient(baseURL: AppConfig.backendBaseURL)
        let downloader = PackDownloader(client: client, packsDirectory: AppConfig.packsDirectory())
        guard let manifest = try? await downloader.fetchManifest() else { return }
        for pack in manifest.packs where pack.slug == slug || pack.slug == "core" {
            if (try? await downloader.download(slug: pack.slug, manifest: manifest)) != nil {
                try? DownloadedPackRecorder(context: context).record(slug: pack.slug, version: pack.version)
            }
        }
    }

    /// Pro: every sport's library on this phone for offline use. Reports
    /// progress as (done, total); returns how many packs failed.
    @discardableResult
    static func installAll(context: ModelContext, progress: @escaping @MainActor (Int, Int) -> Void) async -> Int {
        let client = APIClient(baseURL: AppConfig.backendBaseURL)
        let downloader = PackDownloader(client: client, packsDirectory: AppConfig.packsDirectory())
        guard let manifest = try? await downloader.fetchManifest() else { return -1 }
        let recorder = DownloadedPackRecorder(context: context)
        var failed = 0
        for (index, pack) in manifest.packs.enumerated() {
            progress(index, manifest.packs.count)
            if (try? recorder.isDownloaded(slug: pack.slug, atLeastVersion: pack.version)) == true,
               downloader.locallyAvailablePackFiles().contains(pack.file) { continue }
            if (try? await downloader.download(slug: pack.slug, manifest: manifest)) != nil {
                try? recorder.record(slug: pack.slug, version: pack.version)
            } else {
                failed += 1
            }
        }
        progress(manifest.packs.count, manifest.packs.count)
        return failed
    }
}
