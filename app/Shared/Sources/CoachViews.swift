import SwiftUI

/// §15: "The coach headline from §12" on Today — tap for the full report.
struct CoachHeadlineCard: View {
    let report: CoachReportContent
    let catalogue: Catalogue
    @State private var showingReport = false

    var body: some View {
        Button {
            showingReport = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(AppTheme.inkInverse)
                        .frame(width: 26, height: 26)
                        .background(AppTheme.ink, in: Circle())
                    Text("Your coach")
                        .font(.subheadline.bold())
                        .foregroundStyle(AppTheme.ink)
                    Spacer()
                    Text("Full report")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Text(report.headline)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if !report.recommendations.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(report.recommendations, id: \.itemSlug) { recommendation in
                                Tag(catalogue.item(recommendation.itemSlug)?.name ?? displayName(forSlug: recommendation.itemSlug), color: AppTheme.ink)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingReport) {
            CoachReportSheet(report: report, catalogue: catalogue)
        }
    }
}

/// The whole weekly report: headline, observations, the muscle-balance body
/// map, three recommended exercises from the library, and the closing line.
struct CoachReportSheet: View {
    let report: CoachReportContent
    let catalogue: Catalogue
    @Environment(\.dismiss) private var dismiss
    @State private var detailItem: CatalogueItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle("This week", subtitle: "From your coach — based only on what you logged.")

                    VStack(alignment: .leading, spacing: 14) {
                        Text(report.headline)
                            .font(.title3.bold())
                            .foregroundStyle(AppTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(report.observations, id: \.self) { observation in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundStyle(AppTheme.ink)
                                    .padding(.top, 7)
                                Text(observation)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.ink.opacity(0.85))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()

                    MuscleBalanceCard(balance: report.muscleBalance)

                    if !report.recommendations.isEmpty {
                        SectionTitle("Try these next")
                        ForEach(report.recommendations, id: \.itemSlug) { recommendation in
                            let item = catalogue.item(recommendation.itemSlug)
                            Button {
                                detailItem = item
                            } label: {
                                HStack(spacing: 14) {
                                    ItemThumbnail(item: item, size: 56)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item?.name ?? displayName(forSlug: recommendation.itemSlug))
                                            .font(.headline)
                                            .foregroundStyle(AppTheme.ink)
                                        Text(recommendation.reason)
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.secondaryText)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                                .cardStyle(padding: 12)
                            }
                            .buttonStyle(.plain)
                            .disabled(item == nil)
                        }
                    }

                    if !report.encouragement.isEmpty {
                        Text(report.encouragement)
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 8)
                    }
                }
                .padding(20)
            }
            .appScreen()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.ink)
                }
            }
            .sheet(item: $detailItem) { item in
                NavigationStack { ItemDetailView(item: item) }
            }
        }
    }
}

/// The original idea's "you've only trained arms lately": the last two weeks
/// of logged volume, painted onto the body map region by region, with the
/// top regions and the untouched ones listed underneath.
struct MuscleBalanceCard: View {
    let balance: [MuscleRegion: Double]

    private var weights: [String: Double] {
        let peak = balance.values.max() ?? 0
        guard peak > 0 else { return [:] }
        var result: [String: Double] = [:]
        for muscle in muscles {
            if let share = balance[muscle.region], share > 0 {
                result[muscle.id] = share / peak
            }
        }
        return result
    }

    private var ranked: [(MuscleRegion, Double)] {
        balance.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }

    private var untouched: [MuscleRegion] {
        CoachEngine.majorRegions.filter { (balance[$0] ?? 0) == 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Muscle balance")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Text("Last 14 days")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            if balance.isEmpty {
                Text("Log a few sessions and this fills in — you'll see exactly which muscles you've been training and which you've skipped.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                HStack(spacing: 12) {
                    MuscleMapView(side: .front, weights: weights)
                        .frame(height: 190)
                    MuscleMapView(side: .back, weights: weights)
                        .frame(height: 190)
                }
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

                ForEach(ranked.prefix(4), id: \.0) { region, share in
                    HStack(spacing: 10) {
                        Text(region.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                            .frame(width: 100, alignment: .leading)
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(AppTheme.fill)
                                Capsule()
                                    .fill(AppTheme.brand)
                                    .frame(width: proxy.size.width * share)
                            }
                        }
                        .frame(height: 8)
                        Text("\(Int((share * 100).rounded()))%")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                            .frame(width: 40, alignment: .trailing)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(region.displayName): \(Int((share * 100).rounded())) percent")
                }
                if !untouched.isEmpty {
                    Text("Not trained lately: " + untouched.map { $0.displayName.lowercased() }.joined(separator: ", "))
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
        }
        .cardStyle()
    }
}
