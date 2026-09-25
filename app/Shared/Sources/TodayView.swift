import SwiftData
import SwiftUI

struct LiveSessionLaunch: Identifiable {
    let id = UUID()
    let planned: GeneratedSession?
    var kind: WorkoutKind? = nil
}

enum QuickAction: String, Identifiable, CaseIterable {
    case logWorkout, checkIn, addGame, improve, history, fuel
    var id: String { rawValue }
}

/// One logged session as a list card.
struct SessionRow: View {
    let session: Session

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: session.source == .watch ? "applewatch" : "figure.strengthtraining.traditional")
                .font(.title2)
                .foregroundStyle(AppTheme.ink)
                .frame(width: 64, height: 64)
                .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.startedAt.formatted(.dateTime.weekday(.wide).month().day()))
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Spacer()
                    Text(session.startedAt.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                HStack(spacing: 10) {
                    Label("\(session.minutes) min", systemImage: "clock")
                    Label("\(session.sets.count) sets done", systemImage: "list.bullet")
                    if let rpe = session.sessionRPE {
                        Label("Effort \(rpe)/10", systemImage: "flame")
                    }
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.secondaryText)
                .labelStyle(CompactLabelStyle())
            }
        }
        .cardStyle(padding: 12)
    }
}

struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
            configuration.title
        }
    }
}

/// The "+" sheet: a grid of big tiles for everything that isn't the day's
/// main action.
struct QuickActionsSheet: View {
    let onSelect: (QuickAction) -> Void

    private struct Tile: Identifiable {
        let action: QuickAction
        let title: String
        let detail: String
        let icon: String
        var id: QuickAction { action }
    }

    private let tiles: [Tile] = [
        Tile(action: .logWorkout, title: "Log a workout", detail: "Something you did that isn't in your plan", icon: "figure.run"),
        Tile(action: .checkIn, title: "Check in", detail: "How you slept and feel today", icon: "sun.max.fill"),
        Tile(action: .addGame, title: "Add a game", detail: "Your plan builds up to it", icon: "sportscourt.fill"),
        Tile(action: .improve, title: "Improve a skill", detail: "A plan for one skill, like shooting", icon: "chart.line.uptrend.xyaxis"),
        Tile(action: .fuel, title: "Food & water", detail: "What to eat and drink today", icon: "fork.knife"),
        Tile(action: .history, title: "Past workouts", detail: "Everything you've done", icon: "clock.arrow.circlepath"),
    ]

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(AppTheme.hairline)
                .frame(width: 40, height: 5)
                .padding(.top, 10)
            Text("What do you want to do?")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(tiles) { tile in
                    Button {
                        onSelect(tile.action)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: tile.icon)
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(AppTheme.ink)
                            Text(tile.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.ink)
                            Text(tile.detail)
                                .font(.caption2)
                                .foregroundStyle(AppTheme.secondaryText)
                                .multilineTextAlignment(.center)
                                .lineLimit(2, reservesSpace: true)
                        }
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, minHeight: 126)
                        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .appScreen()
    }
}
