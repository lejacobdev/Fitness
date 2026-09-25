import Foundation
import SwiftData

/// Variant sports were merged into their main sport as formats (beach
/// volleyball is Volleyball, format "beach"). An athlete who picked a variant
/// before the merge keeps everything: their sport, games and skill plans move
/// to the main sport with the matching format, and its pack is installed.
public enum SportAliasMigration {
    /// The main sport and format an old variant slug became, nil if it's still a sport.
    public static func resolve(_ slug: String) -> (sport: String, format: String?)? {
        guard allSportsBySlug[slug] == nil else { return nil }
        for sport in allSports {
            if let format = sport.aliases?[slug] { return (sport.slug, format.isEmpty ? nil : format) }
        }
        return nil
    }

    @MainActor
    public static func migrate(_ context: ModelContext) {
        var changed = false
        var install: Set<String> = []
        for athleteSport in (try? context.fetch(FetchDescriptor<AthleteSport>())) ?? [] {
            guard let target = resolve(athleteSport.sportSlug) else { continue }
            // Already plays the main sport too: keep that one, drop the variant row.
            let siblings = athleteSport.athlete?.sports ?? []
            if let existing = siblings.first(where: { $0.id != athleteSport.id && $0.sportSlug == target.sport }) {
                if existing.formatSlug == nil { existing.formatSlug = target.format }
                if athleteSport.isPrimary, let athlete = athleteSport.athlete { athlete.switchSport(to: existing) }
                context.delete(athleteSport)
            } else {
                athleteSport.sportSlug = target.sport
                if athleteSport.formatSlug == nil { athleteSport.formatSlug = target.format }
            }
            install.insert(target.sport)
            changed = true
        }
        for competition in (try? context.fetch(FetchDescriptor<Competition>())) ?? [] {
            if let target = resolve(competition.sportSlug) { competition.sportSlug = target.sport; changed = true }
        }
        for block in (try? context.fetch(FetchDescriptor<SkillBlock>())) ?? [] {
            if let target = resolve(block.sportSlug) { block.sportSlug = target.sport; changed = true }
        }
        guard changed else { return }
        try? context.save()
        for slug in install {
            Task { await SportPackInstaller.install(slug: slug, context: context) }
        }
    }
}
