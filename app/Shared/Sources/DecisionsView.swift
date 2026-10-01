import SwiftUI

extension PlanDecision {
    /// The decision in plain words (a planning state, not a health label).
    var title: String {
        switch self {
        case .planAsReviewed: "Plan as usual"
        case .modifyOptionalWork: "Lighter or adjusted"
        case .needsClarification: "Needed an answer first"
        case .noExtraTraining: "No added training"
        case .holdForProfessionalReview: "Held: talk to an adult or professional"
        }
    }
}

enum UncertaintyWords {
    static func text(_ code: String) -> String {
        if code == "no_check_in_today" { return "No check-in that day" }
        if code == "practice_effort_not_logged" { return "Practice effort not logged" }
        if code == "schedule_not_set" { return "Practice schedule not set" }
        if code.hasPrefix("history_incomplete_") {
            let days = code.split(separator: "_").compactMap { Int($0) }.first ?? 0
            return "No data on \(days) of the last 14 days — counted as unknown, not as rest"
        }
        return code
    }
}

/// Me → How AthleteOS decides: the rules, in the order they win; every
/// recent decision with its reasons and what was unknown; the sources; and
/// an honest line that nothing has been expert-reviewed yet.
struct DecisionsView: View {
    @Environment(\.dismiss) private var dismiss
    private let traces = DecisionTraceStore.all().reversed()
    private let release = KnowledgeReleaseStore.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ScreenTitle("How AthleteOS decides", subtitle: "Written rules, safety first. You can always stop or say no.")
                    Text("AthleteOS gives general training guidance, not medical advice. Its rules and exercises haven't been reviewed by sports-medicine, coaching or psychology experts yet, so every one is marked draft below. Missing information is shown as unknown, never as rest or as \"cleared\".")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    decisionsSection
                    rulesSection
                    sourcesSection
                    Text("Knowledge release \(release.release)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .containerRelativeFrame(.horizontal)
            }
            .appScreen()
            .toolbar { CloseToolbarItem { dismiss() } }
        }
    }

    private var decisionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Recent decisions")
            if traces.isEmpty {
                Text("Nothing recorded yet. Open Home and it starts.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            ForEach(Array(traces.prefix(30))) { trace in
                TraceCard(trace: trace)
            }
        }
    }

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("The rules, in the order they win")
            ForEach(PlanningRules.all.sorted { $0.priority > $1.priority }) { rule in
                RuleCard(rule: rule, switchedOff: release.disabledRules.contains(rule.id) && !rule.isSafety)
            }
        }
    }

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Sources")
            Text("What each source supports — and what it doesn't. A source never makes a plan certain to work.")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
            ForEach(EvidenceRegistry.sources) { source in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(source.id)  \(source.citation)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(source.scope)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// One day's decision: what was shown, why, and what wasn't known.
private struct TraceCard: View {
    let trace: DecisionTrace

    private var reasons: [String] {
        trace.rules.compactMap { versioned in
            let id = String(versioned.split(separator: "@").first ?? "")
            guard let rule = PlanningRules.all.first(where: { $0.id == id }), rule.decision > .planAsReviewed else { return nil }
            return rule.explanation
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(HealthLine.day(trace.day).capitalized)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Text(trace.decision.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(trace.decision > .modifyOptionalWork ? AppTheme.red : AppTheme.ink)
            }
            Text(trace.selected)
                .font(.subheadline)
                .foregroundStyle(AppTheme.ink)
            ForEach(reasons, id: \.self) { reason in
                Text("• " + reason)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(trace.uncertainties, id: \.self) { code in
                Text("? " + UncertaintyWords.text(code))
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Text("Rules: " + (trace.rules.isEmpty ? "none triggered" : trace.rules.joined(separator: ", ")) + " · release " + trace.knowledgeRelease)
                .font(.caption2.monospaced())
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 14)
    }
}

/// A rule: what it does, its basis, and its review state.
private struct RuleCard: View {
    let rule: PlanningRule
    let switchedOff: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(rule.id)
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Text(switchedOff ? "Switched off" : "Draft · not expert-reviewed")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Text(rule.explanation)
                .font(.subheadline)
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(rule.label.rawValue + ": " + rule.label.meaning + (rule.basis.isEmpty ? "" : " · " + rule.basis.joined(separator: ", ")))
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 14)
    }
}

/// Said honestly on every exercise and sport guide: reviewed by an expert,
/// or general guidance that hasn't been yet.
struct ReviewNote: View {
    let reviewed: Bool
    let subject: String

    var body: some View {
        Label(reviewed ? "Reviewed by an expert." : "General guidance. This \(subject) hasn't been reviewed by an expert yet.",
              systemImage: reviewed ? "checkmark.seal" : "info.circle")
            .font(.caption)
            .foregroundStyle(AppTheme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
    }
}
