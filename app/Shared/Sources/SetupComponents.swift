import SwiftUI

/// The pieces of §15's onboarding (sport → position → season → equipment →
/// coach) as standalone choosers, so first-run setup and the Me tab's edit
/// sheets are literally the same screens.

enum SportIcon {
    static func name(for slug: String) -> String {
        let exact: [String: String] = [
            "soccer": "soccerball", "football": "football.fill", "flag-football": "football.fill",
            "basketball": "basketball.fill", "unified-basketball": "basketball.fill", "wheelchair-basketball": "basketball.fill",
            "baseball": "baseball.fill", "softball": "baseball.fill", "beep-baseball": "baseball.fill",
            "volleyball": "volleyball.fill", "boys-volleyball": "volleyball.fill", "sand-volleyball": "volleyball.fill", "sitting-volleyball": "volleyball.fill",
            "tennis": "tennis.racket", "ice-hockey": "hockey.puck.fill", "inline-hockey": "hockey.puck.fill", "adapted-floor-hockey": "hockey.puck.fill",
            "swimming-diving": "figure.pool.swim", "adapted-swimming": "figure.pool.swim", "water-polo": "figure.pool.swim",
            "cross-country": "figure.run", "track-and-field": "figure.run", "unified-track": "figure.run", "para-track": "figure.run", "orienteering": "figure.run",
            "golf": "figure.golf", "disc-golf": "figure.golf", "wrestling": "figure.wrestling", "judo": "figure.wrestling",
            "skiing": "figure.skiing.downhill", "rowing": "figure.rower", "fencing": "figure.fencing",
            "snowboarding": "figure.snowboarding", "indoor-track-and-field": "figure.run", "unified-sports": "figure.2.arms.open",
            "gymnastics": "figure.gymnastics", "bowling": "figure.bowling", "lacrosse": "figure.lacrosse", "lacrosse-box": "figure.lacrosse",
            "badminton": "figure.badminton", "table-tennis": "figure.table.tennis", "cycling": "bicycle", "mountain-biking": "bicycle", "bmx": "bicycle",
            "weightlifting": "dumbbell.fill", "powerlifting": "dumbbell.fill", "crossfit-style-conditioning": "dumbbell.fill",
            "climbing": "figure.climbing", "surfing": "figure.surfing", "sailing": "sailboat.fill", "archery": "target", "rifle": "scope",
            "competitive-dance": "figure.dance", "step-team": "figure.dance", "competitive-spirit": "megaphone.fill", "cheerleading-sideline": "megaphone.fill",
            "equestrian": "figure.equestrian.sports", "skateboarding": "figure.skateboarding",
        ]
        return exact[slug] ?? "sportscourt.fill"
    }
}

enum SeasonDefaults {
    /// Winter sports (basketball: Nov–March) wrap into the next year — an
    /// end month numerically below the start month means "next year".
    static func dates(for sport: SportInfo, calendar: Calendar = .current, now: Date = .now) -> (start: Date, end: Date) {
        let year = calendar.component(.year, from: now)
        let startMonth = sport.monthRange.first ?? 1
        let endMonth = sport.monthRange.count > 1 ? sport.monthRange[1] : startMonth
        let endYear = endMonth < startMonth ? year + 1 : year
        let start = calendar.date(from: DateComponents(year: year, month: startMonth, day: 1)) ?? now
        let end = calendar.date(from: DateComponents(year: endYear, month: endMonth + 1, day: 0)) ?? start
        return (start, end)
    }

    static func label(_ season: String) -> String {
        season.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

enum EquipmentCatalog {
    /// Everything an athlete might own. `.none` tags (a wall, a step) are
    /// assumed and never asked about.
    static let options: [(level: EquipmentLevel, tags: [String])] = [
        (.minimal, equipmentLevelByTag.filter { $0.value == .minimal }.map(\.key).sorted()),
        (.full, equipmentLevelByTag.filter { $0.value == .full }.map(\.key).sorted()),
    ]

    static func title(for level: EquipmentLevel) -> String {
        switch level {
        case .none: "Bodyweight"
        case .minimal: "Kit you can carry"
        case .full: "Gym equipment"
        }
    }
}

struct SportChooser: View {
    @Binding var selection: String?
    @State private var searchText = ""

    private var sports: [SportInfo] {
        FuzzySearch.rank(allSports.sorted { $0.name < $1.name }, query: searchText, fields: CatalogueSearch.fields)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.secondaryText)
                TextField("Search \(allSports.count) sports", text: $searchText)
                    .foregroundStyle(AppTheme.ink)
            }
            .padding(14)
            .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))

            // The featured sports first; everything else under "More sports".
            // While searching, one ranked list.
            if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                sportList(sports.filter { $0.featured == true })
                Text("More sports")
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.ink)
                    .padding(.top, 8)
                sportList(sports.filter { $0.featured != true })
            } else {
                sportList(sports)
            }
            if sports.isEmpty {
                Text("No sport matches \"\(searchText)\".")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    private func sportList(_ list: [SportInfo]) -> some View {
        LazyVStack(spacing: 10) {
            ForEach(list, id: \.slug) { sport in
                Button {
                    selection = sport.slug
                } label: {
                    OptionRow(
                        title: sport.name, subtitle: SeasonDefaults.label(sport.season) + " season",
                        systemImage: SportIcon.name(for: sport.slug), isSelected: selection == sport.slug
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct PositionChooser: View {
    let sport: SportInfo
    @Binding var selection: String?
    /// The sport's format (beach, sitting…), when it has more than one; nil is the first, standard one.
    var format: Binding<String?>? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let format, !sport.formatList.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("How you play")
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.ink)
                    ForEach(Array(sport.formatList.enumerated()), id: \.element.slug) { index, option in
                        let isSelected = format.wrappedValue == option.slug || (format.wrappedValue == nil && index == 0)
                        Button {
                            format.wrappedValue = index == 0 ? nil : option.slug
                        } label: {
                            OptionRow(title: option.name, systemImage: SportIcon.name(for: sport.slug), isSelected: isSelected)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if !sport.positions.isEmpty {
                if format != nil, !sport.formatList.isEmpty {
                    Text("Position")
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.ink)
                }
                positions
            }
        }
    }

    private var positions: some View {
        VStack(spacing: 10) {
            Button {
                selection = nil
            } label: {
                OptionRow(title: "No specific position", subtitle: "Train for the sport as a whole", systemImage: "person.fill", isSelected: selection == nil)
            }
            .buttonStyle(.plain)
            ForEach(sport.positions, id: \.slug) { position in
                Button {
                    selection = position.slug
                } label: {
                    OptionRow(
                        title: position.name,
                        subtitle: position.qualityProfile.sorted { $0.value > $1.value }.prefix(2)
                            .compactMap { qualitiesBySlug[$0.key]?.shortName }.joined(separator: " · "),
                        systemImage: "person.fill.checkmark", isSelected: selection == position.slug
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct SeasonEditor: View {
    @Binding var start: Date
    @Binding var end: Date

    private var weeks: Int {
        max(0, (Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0) / 7)
    }

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                DatePicker(selection: $start, displayedComponents: .date) {
                    Label("Season starts", systemImage: "flag.fill")
                        .foregroundStyle(AppTheme.ink)
                }
                .padding(.vertical, 10)
                Divider().overlay(AppTheme.hairline)
                DatePicker(selection: $end, in: start..., displayedComponents: .date) {
                    Label("Season ends", systemImage: "flag.checkered")
                        .foregroundStyle(AppTheme.ink)
                }
                .padding(.vertical, 10)
            }
            .tint(AppTheme.accent)
            .cardStyle(padding: 16)
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .foregroundStyle(AppTheme.blue)
                Text("\(weeks) weeks of season. You'll get stronger before it, stay fresh during it, and recover after it.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(padding: 14)
        }
    }
}

struct EquipmentChooser: View {
    @Binding var selection: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                Image(systemName: "figure.strengthtraining.functional")
                    .foregroundStyle(AppTheme.green)
                Text("No equipment? No problem — there's always a bodyweight option.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .cardStyle(padding: 14)

            ForEach(EquipmentCatalog.options, id: \.level) { group in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(EquipmentCatalog.title(for: group.level))
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                        Spacer()
                        let allSelected = Set(group.tags).isSubset(of: selection)
                        Button(allSelected ? "Clear" : "Select all") {
                            if allSelected {
                                selection.subtract(group.tags)
                            } else {
                                selection.formUnion(group.tags)
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                    }
                    FlowLayout(spacing: 8) {
                        ForEach(group.tags, id: \.self) { tag in
                            Button {
                                if selection.contains(tag) { selection.remove(tag) } else { selection.insert(tag) }
                            } label: {
                                Chip(displayName(forSlug: tag), isSelected: selection.contains(tag))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

struct CoachChooser: View {
    @Binding var selection: Bool?

    var body: some View {
        VStack(spacing: 10) {
            Button {
                selection = true
            } label: {
                OptionRow(title: "Yes, I train with a coach", subtitle: "Unlocks coached lifts like the power clean", systemImage: "person.2.fill", isSelected: selection == true)
            }
            .buttonStyle(.plain)
            Button {
                selection = false
            } label: {
                OptionRow(title: "Not right now", subtitle: "You'll only get moves that are safe to learn on your own — change this any time", systemImage: "person.fill", isSelected: selection == false)
            }
            .buttonStyle(.plain)
        }
    }
}
