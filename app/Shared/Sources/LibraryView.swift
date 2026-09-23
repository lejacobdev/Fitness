import SwiftUI

extension MuscleRegion {
    var displayName: String {
        rawValue.replacingOccurrences(of: "-", with: " ").capitalized
    }
}

enum EquipmentFilter: String, CaseIterable, Identifiable {
    case any, bodyweight, minimal, full
    var id: String { rawValue }

    var title: String {
        switch self {
        case .any: "Any equipment"
        case .bodyweight: "Bodyweight"
        case .minimal: "Minimal kit"
        case .full: "Full gym"
        }
    }

    func allows(_ item: CatalogueItem) -> Bool {
        // Explicitly typed: `?? .none` against an Optional would resolve to
        // Optional.none, not EquipmentLevel.none.
        let level: EquipmentLevel = item.equipment.map { equipmentLevelByTag[$0, default: .full] }.max() ?? EquipmentLevel.none
        switch self {
        case .any: return true
        case .bodyweight: return level == EquipmentLevel.none
        case .minimal: return level <= EquipmentLevel.minimal
        case .full: return true
        }
    }
}

/// §15 Tab 4: "Browse every item in the downloaded packs, filterable by
/// quality, equipment, surface and muscle. A body-map picker: tap a muscle
/// to filter."
public struct LibraryView: View {
    @State private var catalogue = Catalogue()
    @State private var searchText = ""
    @State private var group: QualityGroup?
    @State private var equipment: EquipmentFilter = .any
    @State private var kind: String?
    @State private var surface: String?
    @State private var region: MuscleRegion?
    @State private var showingMusclePicker = false
    @State private var showingFilters = false
    @State private var mySportOnly = false
    let athlete: Athlete?

    public init(athlete: Athlete? = nil) {
        self.athlete = athlete
    }

    private var sportSlug: String? { athlete?.activeSport?.sportSlug }
    private var sportName: String? { sportSlug.flatMap { allSportsBySlug[$0]?.name } }

    private var allItems: [CatalogueItem] {
        catalogue.itemsBySlug.values.sorted { $0.name < $1.name }
    }

    private var surfaces: [String] {
        Array(Set(allItems.map(\.surface))).sorted()
    }

    private var filteredItems: [CatalogueItem] {
        allItems.filter { item in
            (searchText.isEmpty || item.name.localizedCaseInsensitiveContains(searchText))
                && (group == nil || item.qualities.contains { entry in entry.value >= 0.5 && qualitiesBySlug[entry.key]?.group == group })
                && equipment.allows(item)
                && (kind == nil || item.kind == kind)
                && (surface == nil || item.surface == surface)
                && (!mySportOnly || (sportSlug != nil && item.itemSportSlug == sportSlug))
                && (region == nil || item.muscles.contains { entry in entry.value >= 0.5 && musclesBySlug[entry.key]?.region == region })
        }
    }

    private var activeFilterCount: Int {
        [equipment != .any, kind != nil, surface != nil].filter { $0 }.count
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14, pinnedViews: []) {
                    ScreenTitle("Library", subtitle: "\(allItems.count) exercises and drills, all offline.")
                    TipCard(id: "library", icon: "play.rectangle.fill", title: "Every move, animated",
                            message: "Tap any exercise to watch how it's done and see the muscles it works in red. Press Try it now to do it on its own.")
                    searchRow
                    groupChips
                    if let region {
                        activeRegionRow(region)
                    }
                    Text("\(filteredItems.count) results")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                    if catalogue.itemsBySlug.isEmpty {
                        emptyState
                    } else {
                        ForEach(filteredItems) { item in
                            NavigationLink {
                                ItemDetailView(item: item)
                            } label: {
                                LibraryRow(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .appScreen()
            .toolbar(.hidden, for: .navigationBar)
            .task { catalogue = CatalogueLoader.load(from: AppConfig.packsDirectory()) }
            .sheet(isPresented: $showingMusclePicker) {
                MusclePickerSheet(selection: $region)
            }
            .sheet(isPresented: $showingFilters) {
                LibraryFilterSheet(equipment: $equipment, kind: $kind, surface: $surface, surfaces: surfaces)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var searchRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.secondaryText)
                TextField("Search exercises", text: $searchText)
                    .foregroundStyle(AppTheme.ink)
            }
            .padding(14)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)

            Button {
                showingMusclePicker = true
            } label: {
                Image(systemName: "figure.stand")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(region == nil ? AppTheme.ink : AppTheme.inkInverse)
                    .frame(width: 50, height: 50)
                    .background(region == nil ? AppTheme.card : AppTheme.ink, in: RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Filter by muscle")

            Button {
                showingFilters = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(activeFilterCount == 0 ? AppTheme.ink : AppTheme.inkInverse)
                        .frame(width: 50, height: 50)
                        .background(activeFilterCount == 0 ? AppTheme.card : AppTheme.ink, in: RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))
                    if activeFilterCount > 0 {
                        Text("\(activeFilterCount)")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(AppTheme.brand, in: Circle())
                            .offset(x: 5, y: -5)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("More filters")
        }
    }

    private var groupChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button { group = nil; mySportOnly = false } label: { Chip("All", isSelected: group == nil && !mySportOnly) }
                    .buttonStyle(.plain)
                if let sportName {
                    Button { mySportOnly.toggle() } label: { Chip("\(sportName) drills", isSelected: mySportOnly) }
                        .buttonStyle(.plain)
                }
                ForEach(QualityGroup.allCases, id: \.self) { value in
                    Button { group = group == value ? nil : value } label: {
                        Chip(value.displayName, isSelected: group == value)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func activeRegionRow(_ region: MuscleRegion) -> some View {
        HStack {
            Label(region.displayName, systemImage: "figure.stand")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
            Spacer()
            Button("Clear") { self.region = nil }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .cardStyle(padding: 14)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "books.vertical")
                .font(.system(size: 30))
                .foregroundStyle(AppTheme.secondaryText)
            Text("Nothing downloaded yet")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)
            Text("Your sport's library downloads the first time you're online.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: 28)
    }
}

struct LibraryRow: View {
    let item: CatalogueItem

    var body: some View {
        HStack(spacing: 14) {
            ItemThumbnail(item: item)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.name)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Text("\(item.kind == "drill" ? "Drill" : "Exercise") · \(DoseFormatter.text(item.defaultDose))")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                if let quality = item.primaryQuality {
                    Tag(quality.shortName, color: quality.group.color)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .cardStyle(padding: 12)
    }
}

/// The body-map picker: a region list beside a live muscle map that lights
/// up whatever region is chosen.
struct MusclePickerSheet: View {
    @Binding var selection: MuscleRegion?
    @Environment(\.dismiss) private var dismiss
    @State private var pending: MuscleRegion?

    private var highlight: [String: Double] {
        guard let pending else { return [:] }
        return Dictionary(uniqueKeysWithValues: muscles.filter { $0.region == pending }.map { ($0.id, 1.0) })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle("Filter by muscle", subtitle: "Pick a body area to see what trains it.")
                    HStack(spacing: 12) {
                        MuscleMapView(side: .front, weights: highlight)
                            .frame(height: 220)
                        MuscleMapView(side: .back, weights: highlight)
                            .frame(height: 220)
                    }
                    .frame(maxWidth: .infinity)
                    .cardStyle()
                    .accessibilityHidden(true)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(MuscleRegion.allCases, id: \.self) { region in
                            Button {
                                pending = pending == region ? nil : region
                            } label: {
                                Chip(region.displayName, isSelected: pending == region)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button("Show results") {
                        selection = pending
                        dismiss()
                    }
                    .buttonStyle(.primary)
                }
                .padding(20)
            }
            .appScreen()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppTheme.ink)
                }
            }
            .onAppear { pending = selection }
        }
    }
}

struct LibraryFilterSheet: View {
    @Binding var equipment: EquipmentFilter
    @Binding var kind: String?
    @Binding var surface: String?
    let surfaces: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ScreenTitle("Filters")
                    filterGroup("Equipment") {
                        ForEach(EquipmentFilter.allCases) { value in
                            Button { equipment = value } label: { Chip(value.title, isSelected: equipment == value) }
                                .buttonStyle(.plain)
                        }
                    }
                    filterGroup("Type") {
                        Button { kind = nil } label: { Chip("All", isSelected: kind == nil) }
                            .buttonStyle(.plain)
                        Button { kind = "exercise" } label: { Chip("Exercises", isSelected: kind == "exercise") }
                            .buttonStyle(.plain)
                        Button { kind = "drill" } label: { Chip("Sport drills", isSelected: kind == "drill") }
                            .buttonStyle(.plain)
                    }
                    filterGroup("Surface") {
                        Button { surface = nil } label: { Chip("Anywhere", isSelected: surface == nil) }
                            .buttonStyle(.plain)
                        ForEach(surfaces, id: \.self) { value in
                            Button { surface = value } label: { Chip(value.capitalized, isSelected: surface == value) }
                                .buttonStyle(.plain)
                        }
                    }
                    HStack(spacing: 12) {
                        Button("Reset") {
                            equipment = .any
                            kind = nil
                            surface = nil
                        }
                        .buttonStyle(.secondary)
                        Button("Done") { dismiss() }
                            .buttonStyle(.primary)
                    }
                }
                .padding(20)
            }
            .appScreen()
        }
    }

    private func filterGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.ink)
            FlowLayout(spacing: 8) {
                content()
            }
        }
    }
}

/// Wraps chips onto as many lines as they need.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width.isFinite ? width : x, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Item detail: the looping pose on a gray hero, the muscle map, then every
/// §7 field in its own card.
struct ItemDetailView: View {
    let item: CatalogueItem
    @Environment(\.dismiss) private var dismiss
    @AppStorage("libraryOpened") private var libraryOpened = false

    private var muscleNames: [String] {
        item.muscles.sorted { $0.value > $1.value }.compactMap { musclesBySlug[$0.key]?.plainName }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZStack(alignment: .topLeading) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                            .fill(AppTheme.fill)
                        if let pair = item.posePair {
                            RigPoseView(start: pair.start, end: pair.end, loops: pair.loops, prop: item.prop.flatMap { propsBySlug[$0] }, muscles: item.muscles)
                                .padding(24)
                        }
                    }
                    .frame(height: 280)
                    CircleIconButton(systemImage: "chevron.left", accessibilityLabel: "Back") { dismiss() }
                        .padding(14)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(item.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(AppTheme.ink)
                    FlowLayout(spacing: 6) {
                        Tag(item.kind == "drill" ? "Sport drill" : "Exercise", color: AppTheme.ink)
                        ForEach(item.qualities.sorted { $0.value > $1.value }.prefix(3), id: \.key) { entry in
                            if let quality = qualitiesBySlug[entry.key] {
                                Tag(quality.shortName, color: quality.group.color)
                            }
                        }
                        if item.isCoached {
                            Tag("Coached only", color: AppTheme.brand)
                        }
                    }
                }

                StartWorkoutButton("Try it now", session: .single(item))

                HStack(spacing: 12) {
                    factCard(DoseFormatter.text(item.defaultDose), "Dose", "repeat")
                    factCard("\(item.restSeconds)s", "Rest", "timer")
                    factCard(item.surface.capitalized, "Where", "mappin.and.ellipse")
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Muscles worked")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    HStack(spacing: 12) {
                        MuscleMapView(side: .front, weights: item.muscles)
                            .frame(height: 190)
                        MuscleMapView(side: .back, weights: item.muscles)
                            .frame(height: 190)
                    }
                    .frame(maxWidth: .infinity)
                    Text(muscleNames.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .cardStyle()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Muscles worked: \(muscleNames.joined(separator: ", "))")

                if !item.equipment.isEmpty {
                    listCard("Equipment", item.equipment.map(displayName(forSlug:)), icon: "bag.fill")
                }
                listCard("Setup", item.setup, icon: "1.circle.fill")
                listCard("How to do it", item.execution, icon: "play.circle.fill")
                listCard("Coaching cues", item.cues, icon: "megaphone.fill")
                listCard("Common mistakes", item.mistakes, icon: "exclamationmark.triangle.fill")
                if !item.progressions.isEmpty {
                    listCard("Make it harder", item.progressions.map(displayName(forSlug:)), icon: "arrow.up.circle.fill")
                }
                if !item.regressions.isEmpty {
                    listCard("Make it easier", item.regressions.map(displayName(forSlug:)), icon: "arrow.down.circle.fill")
                }
                if !item.substitutes.isEmpty {
                    listCard("Swap for", item.substitutes.map(displayName(forSlug:)), icon: "arrow.left.arrow.right.circle.fill")
                }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .appScreen()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { libraryOpened = true }
    }

    private func factCard(_ value: String, _ label: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 14)
    }

    @ViewBuilder
    private func listCard(_ title: String, _ lines: [String], icon: String) -> some View {
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: icon)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(AppTheme.ink)
                            .frame(width: 5, height: 5)
                            .padding(.top, 7)
                        Text(line)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.ink.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
    }
}
