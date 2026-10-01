import SwiftUI

/// Mental skills as practice opportunities, never guaranteed results
/// (Backend Knowledge System §17–21). Each is optional: the athlete can say
/// "no thanks" with no penalty, and after trying one says whether it helped
/// — a skill that keeps not helping is set aside. Scripts are practitioner
/// heuristics [H], not proven sequences; none is a treatment.
public enum MentalSkill: String, CaseIterable, Identifiable, Sendable {
    case focusCue, selfTalk, mistakeReset, pressureLadder, preparation, valuesToAction

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .focusCue: "One focus cue"
        case .selfTalk: "Self-talk cues"
        case .mistakeReset: "Reset after a mistake"
        case .pressureLadder: "Pressure ladder"
        case .preparation: "Preparation evidence"
        case .valuesToAction: "What matters this week"
        }
    }

    public var oneLine: String {
        switch self {
        case .focusCue: "One short cue for the task — not five instructions."
        case .selfTalk: "Your own words for doing, effort, resetting and preparing."
        case .mistakeReset: "Notice it, a neutral cue, the next useful action."
        case .pressureLadder: "Practise a routine under a little more pressure, step by step."
        case .preparation: "Before an event: what you practised, what you can do, your plan B."
        case .valuesToAction: "One small action this week that's in your control."
        }
    }

    public var steps: [String] {
        switch self {
        case .focusCue: [
            "Pick one cue with your coach, e.g. \"Smooth through the target\".",
            "Try it in an easy part of practice.",
            "Did it make the task clearer? Keep it, change it, or drop it.",
            "A cue that helps one task can distract in another — that's normal.",
        ]
        case .selfTalk: [
            "Doing it: \"Smooth through the target.\"",
            "Effort: \"One rep at a time.\"",
            "After a mistake: \"Next action.\"",
            "Before: \"I know my first step.\"",
            "Use your own words. You never have to think only positive thoughts.",
        ]
        case .mistakeReset: [
            "Notice what happened — no judging yet.",
            "Say your neutral cue, e.g. \"Next action\".",
            "Choose the next useful action and do it.",
            "Later, not in the moment: what happened, what was in your control, what will you try?",
        ]
        case .pressureLadder: [
            "Step 1: run your routine with nothing at stake.",
            "Step 2: add a small scoring challenge in practice.",
            "Step 3: a game-like moment you and your coach agree on.",
            "Go up only when you want to. It's about using a skill under some pressure, not about discomfort.",
        ]
        case .preparation: [
            "One thing you practised for this.",
            "One thing you can do well, for sure.",
            "One response if the first try goes badly.",
        ]
        case .valuesToAction: [
            "What matters to you about your sport this week?",
            "Pick one small action in your control: arrive prepared, ask your coach one question, practise a cue, or take your rest day.",
            "At the end of the week: did it feel useful?",
        ]
        }
    }

    public var label: EvidenceLabel {
        switch self {
        case .selfTalk, .valuesToAction: .moderate
        default: .heuristic
        }
    }

    public var basis: [String] {
        switch self {
        case .focusCue: ["R25", "R26"]
        case .selfTalk: ["R24"]
        case .mistakeReset, .pressureLadder: ["R21"]
        case .preparation, .valuesToAction: ["R22", "R23"]
        }
    }
}

/// What the athlete said about each skill: helped, didn't, or no thanks.
public enum MentalSkillFeedback {
    static let key = "mindset.skillFeedback"

    /// "skill=helped" / "skill=notHelpful" / "skill=declined:YYYY-MM-DD" entries.
    static var entries: [String] {
        get { UserDefaults.standard.stringArray(forKey: key) ?? [] }
        set { UserDefaults.standard.set(Array(newValue.suffix(200)), forKey: key) }
    }

    public static func record(_ skill: MentalSkill, helped: Bool) {
        entries.append("\(skill.rawValue)=\(helped ? "helped" : "notHelpful")")
    }

    /// "No thanks": hidden for two weeks, no penalty, nothing else changes.
    public static func decline(_ skill: MentalSkill, now: Date = .now) {
        entries.append("\(skill.rawValue)=declined:\(DayKey.of(now))")
    }

    public static func isDeclined(_ skill: MentalSkill, now: Date = .now) -> Bool {
        guard let last = entries.last(where: { $0.hasPrefix(skill.rawValue + "=declined:") }),
              let day = last.split(separator: ":").last else { return false }
        let since = DayKey.of(Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now)
        return String(day) > since
    }

    /// Set aside once it has clearly not helped more often than it helped.
    public static func isRetired(_ skill: MentalSkill) -> Bool {
        let mine = entries.filter { $0.hasPrefix(skill.rawValue + "=") }
        let helped = mine.filter { $0.hasSuffix("=helped") }.count
        let not = mine.filter { $0.hasSuffix("=notHelpful") }.count
        return not >= 2 && not > helped
    }

    public static func clear(_ skill: MentalSkill) {
        entries.removeAll { $0.hasPrefix(skill.rawValue + "=") }
    }
}

/// Mindset → Mental skills: the list, quiet about anything declined.
struct MentalSkillsSection: View {
    @State private var open: MentalSkill?
    @State private var revision = 0
    @State private var drafting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Mental skills", subtitle: "Optional practice. Say no thanks any time.")
            let _ = revision
            VStack(spacing: 0) {
                ForEach(MentalSkill.allCases.filter { !MentalSkillFeedback.isDeclined($0) }) { skill in
                    Button { open = skill } label: {
                        ListRow(systemImage: "brain.head.profile", color: AppTheme.ink, title: skill.title,
                                detail: MentalSkillFeedback.isRetired(skill) ? "You said it didn't help — set aside" : skill.oneLine)
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 54)
                }
                Button { drafting = true } label: {
                    ListRow(systemImage: "text.bubble", color: AppTheme.ink, title: "Talking to your coach or a parent",
                            detail: "A draft you can change and send yourself")
                }
                .buttonStyle(.plain)
            }
            .cardStyle(padding: 12)
        }
        .sheet(item: $open, onDismiss: { revision += 1 }) { skill in
            MentalSkillSheet(skill: skill)
        }
        .sheet(isPresented: $drafting) {
            ConversationDraftsView()
        }
    }
}

struct MentalSkillSheet: View {
    let skill: MentalSkill
    @Environment(\.dismiss) private var dismiss
    @State private var answered = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenTitle(skill.title, subtitle: skill.oneLine)
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(skill.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(AppTheme.onAccent)
                                    .frame(width: 28, height: 28)
                                    .background(AppTheme.accent, in: Circle())
                                Text(step)
                                    .font(.body)
                                    .foregroundStyle(AppTheme.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                    Text("A practice option, not a promise: results vary by person and task. \(skill.label.rawValue) · \(skill.basis.joined(separator: ", ")) (Me → How AthleteOS decides).")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    if answered {
                        Label("Thanks — noted.", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(AppTheme.green)
                    } else {
                        Text("Tried it? Did it help?")
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                        ButtonRow {
                            Button("It helped") { MentalSkillFeedback.record(skill, helped: true); answered = true }
                                .buttonStyle(.secondary)
                            Button("Not really") { MentalSkillFeedback.record(skill, helped: false); answered = true }
                                .buttonStyle(.secondary)
                        }
                    }
                    Button("No thanks — hide it for now") {
                        MentalSkillFeedback.decline(skill)
                        dismiss()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    if MentalSkillFeedback.isRetired(skill) {
                        Button("Give it another try") { MentalSkillFeedback.clear(skill); dismiss() }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .containerRelativeFrame(.horizontal)
            }
            .appScreen()
            .toolbar { CloseToolbarItem { dismiss() } }
        }
    }
}

/// Talking to a coach or parent (§21): a draft the athlete changes and sends
/// themselves. Nothing is ever sent by the app.
struct ConversationDraftsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var situation = 0
    @State private var text = ConversationDraftsView.drafts[0].draft

    static let drafts: [(title: String, draft: String)] = [
        ("My role is unclear", "Which two things should I focus on to help the team?"),
        ("Too much training at once", "I have practice with both teams this week. Can we look at the extra training together?"),
        ("Something hurts", "This movement is hurting and changing how I play. I need help deciding what to do."),
        ("I'd like feedback", "Could you tell me one thing I'm doing well and one thing to work on?"),
        ("We see it differently", "I understood the plan differently. Can we clarify it?"),
        ("A teammate made a mistake", "Let's reset and organise the next play."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenTitle("Talking it through", subtitle: "Pick what it's about, make the words yours, send it yourself.")
                    WrapLayout(spacing: 8) {
                        ForEach(Self.drafts.indices, id: \.self) { index in
                            Button {
                                situation = index
                                text = Self.drafts[index].draft
                            } label: { Chip(Self.drafts[index].title, isSelected: situation == index) }
                            .buttonStyle(.plain)
                        }
                    }
                    TextField("Your message", text: $text, axis: .vertical)
                        .lineLimit(3...8)
                        .padding(16)
                        .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))
                    #if os(iOS) && !APP_EXTENSION
                    ShareLink(item: text) {
                        Label("Send it…", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.primary)
                    #endif
                    Text("If someone is hurting, pressuring or scaring you, don't sort it out alone: tell a different adult you trust (Me → Safety Center → Talk to an adult).")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .containerRelativeFrame(.horizontal)
            }
            .appScreen()
            .toolbar { CloseToolbarItem { dismiss() } }
        }
    }
}
