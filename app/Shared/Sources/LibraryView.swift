import SwiftUI

/// §15 Tab 4: "Browse every item in the downloaded packs... Item detail
/// shows the looping pose pair, the red muscle map, setup, execution, cues,
/// mistakes, progressions and substitutes." This is where §9's rendering
/// infrastructure (MuscleMapView, RigPoseView) actually lives in the real
/// app — not a compiled-in demo screen, real items from whatever the
/// athlete has downloaded.
public struct LibraryView: View {
    @State private var catalogue = Catalogue()
    @State private var searchText = ""

    public init() {}

    private var filteredItems: [CatalogueItem] {
        let items = catalogue.itemsBySlug.values.sorted { $0.name < $1.name }
        guard !searchText.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    public var body: some View {
        NavigationStack {
            List(filteredItems, id: \.slug) { item in
                NavigationLink {
                    LibraryItemDetailView(item: item)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("\(item.kind.capitalized) · \(item.equipment.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .searchable(text: $searchText, prompt: "Search your library")
            .overlay {
                if catalogue.itemsBySlug.isEmpty {
                    ContentUnavailableView(
                        "Nothing downloaded yet", systemImage: "books.vertical",
                        description: Text("Pick a sport in onboarding to download its library.")
                    )
                    .foregroundStyle(.white)
                }
            }
            .background(AppBackground())
            .navigationTitle("Library")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                catalogue = CatalogueLoader.load(from: AppConfig.packsDirectory())
            }
        }
    }
}

private struct LibraryItemDetailView: View {
    let item: CatalogueItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(item.name)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                if let pair = item.posePair {
                    RigPoseView(start: pair.start, end: pair.end, prop: item.prop.flatMap { propsBySlug[$0] })
                        .frame(height: 220)
                        .cardStyle()
                }

                HStack(spacing: 16) {
                    MuscleMapView(side: .front, weights: item.muscles)
                        .frame(height: 180)
                    MuscleMapView(side: .back, weights: item.muscles)
                        .frame(height: 180)
                }
                .cardStyle()
                .accessibilityLabel("Muscles worked: \(muscleNames)")

                section("Setup", item.setup)
                section("Execution", item.execution)
                section("Cues", item.cues)
                section("Common mistakes", item.mistakes)

                if !item.progressions.isEmpty {
                    slugSection("Progressions", item.progressions)
                }
                if !item.regressions.isEmpty {
                    slugSection("Regressions", item.regressions)
                }
                if !item.substitutes.isEmpty {
                    slugSection("Substitutes", item.substitutes)
                }
            }
            .padding(20)
        }
        .background(AppBackground())
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var muscleNames: String {
        item.muscles.keys.compactMap { musclesBySlug[$0]?.plainName }.joined(separator: ", ")
    }

    private func section(_ title: String, _ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            ForEach(lines, id: \.self) { line in
                Text("•  \(line)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func slugSection(_ title: String, _ slugs: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text(slugs.joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
