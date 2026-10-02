import SwiftUI

// V6 workout presentation (docs/VERSION-6.md §2, §9): one hero, flat rows,
// one information panel. Not every block in a card.

/// The session's hero: what it is, how long, and the one-sentence why.
struct PlanHero: View {
    let session: GeneratedSession
    let explanation: PlanExplanation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(meta)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
            Text(session.title)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(explanation.summary)
                .font(.body)
                .foregroundStyle(AppTheme.ink.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 12)
    }

    private var meta: String {
        var parts = ["\(session.estimatedMinutes) min"]
        if let type = session.decision?.sessionType, type.title != session.title { parts.append(type.title) }
        return parts.joined(separator: " · ")
    }
}

/// Exercises grouped by block, as flat rows.
struct BlockedSessionList: View {
    let session: GeneratedSession
    let catalogue: Catalogue
    let onOpen: (CatalogueItem) -> Void

    private var groups: [(block: SessionBlock, items: [GeneratedPlannedItem])] {
        var out: [(SessionBlock, [GeneratedPlannedItem])] = []
        for item in session.items {
            let block = item.block ?? .primaryStrength
            if let last = out.indices.last, out[last].0 == block { out[last].1.append(item) } else { out.append((block, [item])) }
        }
        return out.map { (block: $0.0, items: $0.1) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(group.block.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                        Spacer()
                        Text(minutes(group.items))
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(AppTheme.mutedText)
                    }
                    if let why = group.items.first?.rationale, !why.isEmpty {
                        Text(why)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.mutedText)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.bottom, 4)
                    }
                    ForEach(group.items, id: \.order) { item in row(item) }
                }
            }
        }
    }

    private func minutes(_ items: [GeneratedPlannedItem]) -> String {
        let seconds = items.reduce(0) { $0 + SessionBuilder.seconds($1) }
        return "~\(max(1, Int((Double(seconds) / 60).rounded()))) min"
    }

    private func row(_ item: GeneratedPlannedItem) -> some View {
        let catalogueItem = catalogue.item(item.itemSlug)
        return Button { if let catalogueItem { onOpen(catalogueItem) } } label: {
            HStack(spacing: 14) {
                ItemThumbnail(item: catalogueItem)
                VStack(alignment: .leading, spacing: 2) {
                    Text(catalogueItem?.name ?? displayName(forSlug: item.itemSlug))
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                        .multilineTextAlignment(.leading)
                    Text(item.block == .conditioning ? conditioningText(item) : DoseFormatter.text(item.dose))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(catalogueItem == nil)
    }

    /// Conditioning reads as its protocol ("12 × 30 s, 15 s easy between").
    private func conditioningText(_ item: GeneratedPlannedItem) -> String {
        let work = item.dose.seconds ?? 30
        if item.dose.sets <= 1 { return "\(work / 60) min, easy and steady" }
        let w = work >= 60 ? "\(work / 60) min" : "\(work) s"
        let r = item.restSec >= 60 ? "\(item.restSec / 60) min" : "\(item.restSec) s"
        return "\(item.dose.sets) × \(w), \(r) easy between"
    }
}

/// "More about this plan": the ten answers, in one glass panel.
struct WhyThisPlanPanel: View {
    let explanation: PlanExplanation
    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(.easeInOut(duration: 0.25)) { open.toggle() } } label: {
                HStack {
                    Text("Why this plan?")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if open {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(explanation.parts, id: \.question) { part in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(part.question)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.ink)
                            Text(part.answer)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 16)
            }
        }
        .padding(18)
        .glassSurface()
        .padding(.top, 20)
    }
}
