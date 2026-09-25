import SwiftUI
#if os(iOS)
import UIKit
#endif

extension MindsetRoutine: Identifiable {
    public var id: String { rawValue }
}

/// The Mindset hub: this week's progress, the evening reflection, season
/// goals with their weekly focus, and the game-day routines.
struct MindsetView: View {
    let sportName: String
    let onOpenCampus: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var goals = MindsetStore.goals
    @State private var reflections = MindsetStore.reflections
    @State private var editingGoals = false
    @State private var reflecting = false
    @State private var routine: MindsetRoutine?
    /// Bumped after any change so the week's numbers redraw.
    @State private var revision = 0

    private var focus: [FocusPoint] { MindsetEngine.weeklyFocus(goals: goals, weekStart: .now) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle("Mindset", subtitle: "Strong in your head too: reflect for 2 minutes each evening, work on your season goals, and have a routine for game day.")
                    weekCard
                    reflectionSection
                    goalsSection
                    gameDaySection
                    learnSection
                    if reflections.count > 1 { pastWins }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .containerRelativeFrame(.horizontal)
            }
            .scrollIndicators(.hidden)
            .appScreen()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $reflecting) {
                ReflectionSheet {
                    reflections = MindsetStore.reflections
                    revision += 1
                    reflecting = false
                }
            }
            .sheet(isPresented: $editingGoals) {
                SeasonGoalsSheet(goals: goals) { updated in
                    MindsetStore.goals = updated
                    goals = MindsetStore.goals
                    revision += 1
                    editingGoals = false
                }
            }
            .fullScreenCover(item: $routine, onDismiss: { revision += 1 }) { routine in
                switch routine {
                case .breathing: BreathingView()
                case .visualization: VisualizationView(sportName: sportName)
                }
            }
        }
    }

    // MARK: - This week

    private var weekCard: some View {
        _ = revision
        let progress = MindsetStore.weekProgress()
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("This week")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Text("\(progress.done) of \(progress.target)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppTheme.purple)
            }
            ProgressView(value: Double(progress.done), total: Double(max(1, progress.target)))
                .tint(AppTheme.purple)
            Text("Counts: 5 evening reflections, this week's focus for each goal, and one breathing or visualization routine.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle()
    }

    // MARK: - Reflection

    private var reflectionSection: some View {
        _ = revision
        let today = MindsetStore.reflection(on: .now)
        let streak = MindsetStore.reflectionStreak()
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Evening reflection", subtitle: "Two minutes before bed: one win, one lesson. Small wins add up to confidence.")
            if let today {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Done for today\(streak > 1 ? " · \(streak) days in a row" : "")", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(AppTheme.green)
                    reflectionLines(today)
                    Button("Change it") { reflecting = true }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle(padding: 16)
            } else {
                Button { reflecting = true } label: {
                    Label("Reflect now — 2 minutes", systemImage: "moon.stars.fill")
                }
                .buttonStyle(.primary)
                if streak > 0 {
                    Text("\(streak)-day streak — keep it going tonight.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
        }
    }

    private func reflectionLines(_ reflection: Reflection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(reflection.win, systemImage: "star.fill")
                .foregroundStyle(AppTheme.ink)
            Label(reflection.lesson, systemImage: "lightbulb.fill")
                .foregroundStyle(AppTheme.ink)
        }
        .font(.subheadline)
    }

    // MARK: - Goals

    private var goalsSection: some View {
        _ = revision
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Season goals", subtitle: goals.isEmpty
                ? "Up to three goals for this season. Each week you get one small, concrete thing to do for each."
                : "This week's focus for each goal — tick it off when you've done it.")
            ForEach(focus) { point in
                focusRow(point)
            }
            if goals.isEmpty {
                Button { editingGoals = true } label: { Label("Set my season goals", systemImage: "flag.fill") }
                    .buttonStyle(.primary)
            } else {
                Button { editingGoals = true } label: { Label("Change my goals", systemImage: "flag.fill") }
                    .buttonStyle(.secondary)
            }
        }
    }

    private func focusRow(_ point: FocusPoint) -> some View {
        let done = MindsetStore.isFocusDone(point.goal.id)
        return Button {
            MindsetStore.setFocusDone(point.goal.id, !done)
            revision += 1
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(done ? AppTheme.green : AppTheme.secondaryText)
                VStack(alignment: .leading, spacing: 4) {
                    Label(point.goal.text, systemImage: point.goal.area.systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                    Text(point.text)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                        .strikethrough(done)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .cardStyle(padding: 16)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(point.text). \(done ? "Done" : "Not done yet")")
    }

    // MARK: - Game day

    private var gameDaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Before a game", subtitle: "Nerves are normal — they mean you care. These get you calm and sharp.")
            routineButton("2-minute breathing", detail: "Calm your nerves or lock in", icon: "wind", color: AppTheme.ink) { routine = .breathing }
            routineButton("Game-day visualization", detail: "5 minutes: play the game in your head first", icon: "eye.fill", color: AppTheme.purple) { routine = .visualization }
        }
    }

    private func routineButton(_ title: String, detail: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color)
                    .frame(width: 52, height: 52)
                    .background(color.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer(minLength: 0)
                Image(systemName: "play.fill")
                    .foregroundStyle(color)
            }
            .cardStyle(padding: 14)
        }
        .buttonStyle(.plain)
    }

    private var learnSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Learn", subtitle: "Short Campus lessons on confidence, pressure, focus and teamwork.")
            Button {
                dismiss()
                onOpenCampus()
            } label: {
                Label("Open the mindset lessons", systemImage: "graduationcap.fill")
            }
            .buttonStyle(.secondary)
        }
    }

    private var pastWins: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Your wins", subtitle: "Read these before a big game.")
            VStack(alignment: .leading, spacing: 12) {
                ForEach(reflections.prefix(7)) { reflection in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(reflection.day)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                        Label(reflection.win, systemImage: "star.fill")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.ink)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(padding: 16)
        }
    }
}

// MARK: - Reflection

/// "One win, one lesson" — two big fields and done.
struct ReflectionSheet: View {
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var win = MindsetStore.reflection(on: .now)?.win ?? ""
    @State private var lesson = MindsetStore.reflection(on: .now)?.lesson ?? ""
    @State private var feeling: Int? = MindsetStore.reflection(on: .now)?.feeling

    private var canSave: Bool {
        !win.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !lesson.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        StepScaffold(
            title: "Evening reflection",
            subtitle: "Two minutes. Be honest and specific — it's only for you.",
            buttonTitle: "Save", buttonEnabled: canSave,
            onBack: { dismiss() },
            onContinue: {
                MindsetStore.saveReflection(
                    win: win.trimmingCharacters(in: .whitespacesAndNewlines),
                    lesson: lesson.trimmingCharacters(in: .whitespacesAndNewlines),
                    feeling: feeling
                )
                onSaved()
            }
        ) {
            field("One win today", hint: "e.g. I stayed calm after missing the first shot", text: $win, icon: "star.fill", color: AppTheme.amber)
            field("One lesson for tomorrow", hint: "e.g. Call for the ball earlier", text: $lesson, icon: "lightbulb.fill", color: AppTheme.blue)
            VStack(alignment: .leading, spacing: 10) {
                Text("How was today? (optional)")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { value in
                        let faces = ["😣", "😕", "😐", "🙂", "😄"]
                        Button { feeling = feeling == value ? nil : value } label: {
                            Text(faces[value - 1])
                                .font(.system(size: 30))
                                .frame(maxWidth: .infinity, minHeight: 56)
                                .background(feeling == value ? AppTheme.accent.opacity(0.18) : AppTheme.fill,
                                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Feeling \(value) of 5")
                    }
                }
            }
        }
    }

    private func field(_ title: String, hint: String, text: Binding<String>, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(color)
            TextField(hint, text: text, axis: .vertical)
                .lineLimit(2...4)
                .font(.body)
                .padding(16)
                .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

// MARK: - Goals

/// Up to three season goals: pick what it's about, then say it your way.
struct SeasonGoalsSheet: View {
    @State var goals: [SeasonGoal]
    let onSave: ([SeasonGoal]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var area: GoalArea = .performance
    @State private var text = ""

    var body: some View {
        StepScaffold(
            title: "Season goals",
            subtitle: "Up to three. Each week you get one small thing to do for each goal.",
            buttonTitle: "Save", onBack: { dismiss() }, onContinue: { onSave(goals) }
        ) {
            if !goals.isEmpty {
                VStack(spacing: 10) {
                    ForEach(goals) { goal in
                        HStack(spacing: 12) {
                            Image(systemName: goal.area.systemImage)
                                .foregroundStyle(AppTheme.brand)
                                .frame(width: 40, height: 40)
                                .background(AppTheme.brand.opacity(0.12), in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(goal.text)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.ink)
                                Text(goal.area.title)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                            Spacer(minLength: 0)
                            Button { goals.removeAll { $0.id == goal.id } } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(AppTheme.red)
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove goal")
                        }
                        .cardStyle(padding: 12)
                    }
                }
            }

            if goals.count < MindsetEngine.maxGoals {
                VStack(alignment: .leading, spacing: 12) {
                    Text(goals.isEmpty ? "What's your first goal about?" : "Add another goal")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    WrapLayout(spacing: 8) {
                        ForEach(GoalArea.allCases) { value in
                            Button { area = value } label: {
                                Label(value.title, systemImage: value.systemImage)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(area == value ? AppTheme.onAccent : AppTheme.ink)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(area == value ? AppTheme.accent : AppTheme.fill, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    TextField("Your goal, in your words", text: $text, axis: .vertical)
                        .lineLimit(1...3)
                        .padding(16)
                        .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Text("Ideas:")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                    ForEach(area.examples, id: \.self) { example in
                        Button { text = example } label: {
                            Label(example, systemImage: "plus.circle")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.accent)
                                .multilineTextAlignment(.leading)
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        goals.append(SeasonGoal(text: trimmed, area: area))
                        text = ""
                    } label: {
                        Label("Add this goal", systemImage: "plus")
                    }
                    .buttonStyle(.secondary)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Breathing

/// A circle that grows as you breathe in and shrinks as you breathe out.
struct BreathingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pattern: BreathingPattern = .calm
    @State private var minutes = 2
    @State private var startedAt: Date?
    @State private var finished = false
    @State private var lastPhase = -1

    private var total: Double { Double(minutes * 60) }

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .font(.headline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            if let startedAt, !finished {
                TimelineView(.animation) { context in
                    let elapsed = min(total, context.date.timeIntervalSince(startedAt))
                    let phase = pattern.phase(at: elapsed)
                    let hold = phase.label == "Hold"
                    let scale = hold ? (phase.expand ? 1 : 0.5) : (phase.expand ? 0.5 + 0.5 * phase.progress : 1 - 0.5 * phase.progress)
                    VStack(spacing: 28) {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(AppTheme.fill)
                                .frame(width: 280, height: 280)
                            Circle()
                                .fill(AppTheme.solid)
                                .frame(width: 280, height: 280)
                                .scaleEffect(scale)
                            Text(phase.label)
                                .font(.title.bold())
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .padding(40)
                        }
                        .onChange(of: phase.index) { _, index in phaseChanged(index) }
                        Text(remainingText(total - elapsed))
                            .font(.title2.monospacedDigit().weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                        Spacer()
                    }
                }
                .task {
                    try? await Task.sleep(nanoseconds: UInt64(total * 1_000_000_000))
                    guard !Task.isCancelled else { return }
                    MindsetStore.logRoutine(.breathing)
                    finished = true
                }
                Button("Stop") {
                    if let started = self.startedAt, Date.now.timeIntervalSince(started) >= 60 { MindsetStore.logRoutine(.breathing) }
                    dismiss()
                }
                .buttonStyle(.secondary)
            } else if finished {
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(AppTheme.green)
                Text("Nice. Calm and ready.")
                    .font(.largeTitle.bold())
                    .foregroundStyle(AppTheme.ink)
                Text("Use the same breathing whenever the nerves come back — before a free throw, a serve, a start.")
                    .font(.body)
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.primary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ScreenTitle("Breathing", subtitle: "Sit or stand still, relax your shoulders, and follow the circle.")
                        ForEach(BreathingPattern.allCases) { value in
                            Button { pattern = value } label: {
                                OptionRow(title: value.title, subtitle: value.explanation, systemImage: value == .calm ? "wind" : "square", isSelected: pattern == value)
                            }
                            .buttonStyle(.plain)
                        }
                        Text("How long?")
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                        HStack(spacing: 10) {
                            ForEach([1, 2, 3], id: \.self) { value in
                                Button { minutes = value } label: {
                                    Text("\(value) min")
                                        .font(.headline)
                                        .foregroundStyle(minutes == value ? AppTheme.onAccent : AppTheme.ink)
                                        .frame(maxWidth: .infinity, minHeight: 52)
                                        .background(minutes == value ? AppTheme.accent : AppTheme.fill, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                Button { startedAt = .now } label: { Label("Start", systemImage: "play.fill") }
                    .buttonStyle(.primary)
            }
        }
        .padding(24)
        .appScreen()
    }

    private func remainingText(_ seconds: Double) -> String {
        let s = max(0, Int(seconds.rounded(.up)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func phaseChanged(_ index: Int) {
        guard index != lastPhase else { return }
        lastPhase = index
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }
}

// MARK: - Visualization

/// The game-day visualization: seven short steps, each on its own timer.
struct VisualizationView: View {
    let sportName: String

    @Environment(\.dismiss) private var dismiss
    @State private var cueWord = MindsetStore.cueWord
    @State private var step: Int?
    @State private var stepStartedAt = Date.now

    private var steps: [VisualizationStep] { GameDayVisualization.steps(sportName: sportName, cueWord: cueWord) }

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                if let step { StepProgressBar(progress: Double(step + 1) / Double(steps.count)) }
                Spacer()
                Button("Close") { dismiss() }
                    .font(.headline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            if let step, step < steps.count {
                let current = steps[step]
                Spacer()
                VStack(alignment: .leading, spacing: 16) {
                    Text("Step \(step + 1) of \(steps.count)")
                        .font(.caption.weight(.heavy))
                        .tracking(0.8)
                        .foregroundStyle(AppTheme.purple)
                    Text(current.title)
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppTheme.ink)
                    Text(current.text)
                        .font(.title3)
                        .foregroundStyle(AppTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    TimelineView(.periodic(from: stepStartedAt, by: 1)) { context in
                        let left = max(0, current.seconds - Int(context.date.timeIntervalSince(stepStartedAt)))
                        Text(left > 0 ? "\(left) s" : "…")
                            .font(.title2.monospacedDigit().weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .task(id: step) {
                    stepStartedAt = .now
                    try? await Task.sleep(nanoseconds: UInt64(current.seconds) * 1_000_000_000)
                    guard !Task.isCancelled else { return }
                    advance()
                }
                Spacer()
                HStack(spacing: 12) {
                    if step > 0 {
                        Button("Back") { self.step = step - 1 }
                            .buttonStyle(.secondary)
                    }
                    Button(step == steps.count - 1 ? "Finish" : "Next") { advance() }
                        .buttonStyle(.primary)
                }
            } else if step != nil {
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(AppTheme.green)
                Text("You've played it once already.")
                    .font(.largeTitle.bold())
                    .foregroundStyle(AppTheme.ink)
                    .multilineTextAlignment(.center)
                Text("Remember your word: \"\(cueWord)\". Say it after any mistake, then go to the next play.")
                    .font(.body)
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.primary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ScreenTitle("Game-day visualization", subtitle: "About 5 minutes. Find a quiet spot — the locker room, the bus, your bed. You'll picture the game going well, and how you bounce back from a mistake.")
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your reset word")
                                .font(.headline)
                                .foregroundStyle(AppTheme.ink)
                            Text("One word you say in your head after a mistake, to let it go and play the next play.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                            TextField("Next", text: $cueWord)
                                .font(.title3.weight(.semibold))
                                .padding(16)
                                .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            HStack(spacing: 8) {
                                ForEach(["Next", "Reset", "Attack", "Smooth", "Breathe"], id: \.self) { word in
                                    Button(word) { cueWord = word }
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(cueWord == word ? AppTheme.onAccent : AppTheme.ink)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(cueWord == word ? AppTheme.accent : AppTheme.fill, in: Capsule())
                                        .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                Button {
                    let word = cueWord.trimmingCharacters(in: .whitespacesAndNewlines)
                    cueWord = word.isEmpty ? "Next" : word
                    MindsetStore.cueWord = cueWord
                    step = 0
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .buttonStyle(.primary)
            }
        }
        .padding(24)
        .appScreen()
    }

    private func advance() {
        guard let step else { return }
        if step + 1 >= steps.count { MindsetStore.logRoutine(.visualization) }
        self.step = step + 1
    }
}
