import SwiftData
import SwiftUI

/// Me → Reminders: the morning check-in nudge and game-eve reminders.
struct RemindersSheet: View {
    let athlete: Athlete
    @Environment(\.dismiss) private var dismiss
    @State private var settings = ReminderScheduler.settings
    @State private var time = Date.now
    @State private var denied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle("Reminders", subtitle: "A nudge at the right moment — never spam.")

                    VStack(spacing: 0) {
                        Toggle(isOn: $settings.checkInEnabled) {
                            row("Morning check-in", "Four taps to start the day", "sun.max.fill", AppTheme.amber)
                        }
                        .tint(AppTheme.green)
                        .padding(.vertical, 8)
                        if settings.checkInEnabled {
                            Divider().overlay(AppTheme.hairline)
                            DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                                .foregroundStyle(AppTheme.ink)
                                .tint(AppTheme.ink)
                                .padding(.vertical, 10)
                        }
                        Divider().overlay(AppTheme.hairline)
                        Toggle(isOn: $settings.gameRemindersEnabled) {
                            row("Game eve", "The evening before each game", "sportscourt.fill", AppTheme.brand)
                        }
                        .tint(AppTheme.green)
                        .padding(.vertical, 8)
                    }
                    .cardStyle(padding: 16)

                    if denied {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "bell.slash.fill")
                                .foregroundStyle(AppTheme.secondaryText)
                            Text("Notifications are turned off for Student Athlete. Turn them on in the Settings app → Notifications.")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        .cardStyle(padding: 16)
                    }

                    Button("Save", action: save)
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
            .onAppear {
                time = Calendar.current.date(bySettingHour: settings.checkInHour, minute: settings.checkInMinute, second: 0, of: .now) ?? .now
            }
        }
    }

    private func row(_ title: String, _ detail: String, _ icon: String, _ tint: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(AppTheme.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    private func save() {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        settings.checkInHour = parts.hour ?? 7
        settings.checkInMinute = parts.minute ?? 15
        ReminderScheduler.settings = settings
        let games = AthleteStats.upcomingCompetitions(athlete).map { (date: $0.date, kind: $0.kind.rawValue.capitalized) }
        let wantsAny = settings.checkInEnabled || settings.gameRemindersEnabled
        Task {
            if wantsAny {
                let granted = await ReminderScheduler.requestAuthorization()
                if !granted {
                    denied = true
                    return
                }
            }
            await ReminderScheduler.reschedule(games: games)
            dismiss()
        }
    }
}

/// Me → Downloads: which libraries are on this phone, and a refresh.
struct DownloadsSheet: View {
    let athlete: Athlete
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DownloadedPack.packSlug) private var packs: [DownloadedPack]
    @State private var catalogueCount = 0
    @State private var isRefreshing = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle("Downloads", subtitle: "Everything here works with no signal.")

                    HStack(spacing: 12) {
                        stat("\(catalogueCount)", "exercises & drills")
                        stat("\(packs.count)", "libraries")
                    }

                    VStack(spacing: 0) {
                        if packs.isEmpty {
                            Text("Nothing downloaded yet.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                        }
                        ForEach(Array(packs.enumerated()), id: \.element.id) { index, pack in
                            HStack(spacing: 12) {
                                Image(systemName: pack.packSlug == "core" ? "books.vertical.fill" : SportIcon.name(for: pack.packSlug))
                                    .foregroundStyle(AppTheme.ink)
                                    .frame(width: 34, height: 34)
                                    .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pack.packSlug == "core" ? "Core exercise library" : (allSportsBySlug[pack.packSlug]?.name ?? pack.packSlug))
                                        .foregroundStyle(AppTheme.ink)
                                    Text("Version \(pack.version) · \(pack.downloadedAt.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.green)
                            }
                            .padding(.vertical, 10)
                            if index < packs.count - 1 {
                                Divider().overlay(AppTheme.hairline)
                            }
                        }
                    }
                    .cardStyle(padding: 16)

                    if let message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    Button(isRefreshing ? "Checking for updates…" : "Check for updates", action: refresh)
                        .buttonStyle(.primary)
                        .disabled(isRefreshing)
                }
                .padding(20)
            }
            .appScreen()
            .task { catalogueCount = CatalogueLoader.load(from: AppConfig.packsDirectory()).itemsBySlug.count }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.ink)
                }
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(AppTheme.ink)
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 16)
    }

    private func refresh() {
        guard let sport = athlete.sports.first?.sportSlug else { return }
        isRefreshing = true
        message = nil
        Task {
            await SportPackInstaller.install(slug: sport, context: modelContext)
            catalogueCount = CatalogueLoader.load(from: AppConfig.packsDirectory()).itemsBySlug.count
            isRefreshing = false
            message = "Up to date — \(catalogueCount) items on this phone."
        }
    }
}
