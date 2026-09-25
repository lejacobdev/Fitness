import SwiftUI

/// The Campus tab: ten topics of short lessons, plus the exercise library.
/// Lessons marked as learned are remembered on this device.
struct CampusView: View {
    let athlete: Athlete
    @AppStorage("campus.learned") private var learnedRaw = ""
    @State private var showingLibrary = false

    private var learned: Set<String> { Set(learnedRaw.split(separator: ",").map(String.init)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenTitle("Campus", subtitle: "Learn how to train, eat, sleep, think and play like an athlete — a few minutes at a time.")

                    Button { showingLibrary = true } label: {
                        CampusCard(title: "Exercise library", subtitle: "Every exercise and drill, animated.", systemImage: "books.vertical.fill", progress: nil)
                    }
                    .buttonStyle(.plain)

                    SectionHeader("Topics", subtitle: "\(learned.count) of \(campusTopics.reduce(0) { $0 + $1.lessons.count }) lessons learned")
                    ForEach(campusTopics) { topic in
                        NavigationLink(value: topic) {
                            let done = topic.lessons.filter { learned.contains($0.id) }.count
                            CampusCard(title: topic.title, subtitle: topic.subtitle, systemImage: topic.systemImage,
                                       progress: Double(done) / Double(max(1, topic.lessons.count)), detail: "\(done)/\(topic.lessons.count)")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .appScreen()
            .navigationDestination(for: CampusTopic.self) { topic in
                CampusTopicView(topic: topic, learnedRaw: $learnedRaw)
            }
            .sheet(isPresented: $showingLibrary) {
                LibraryView(athlete: athlete)
            }
        }
    }
}

private struct CampusCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let progress: Double?
    var detail: String? = nil

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(AppTheme.onAccent)
                .frame(width: 58, height: 58)
                .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.ink)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if let progress {
                RingView(progress: progress, color: AppTheme.accent, lineWidth: 5) {
                    Text(detail ?? "")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.ink)
                }
                .frame(width: 50, height: 50)
            } else {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 18)
        .contentShape(Rectangle())
    }
}

private struct CampusTopicView: View {
    let topic: CampusTopic
    @Binding var learnedRaw: String

    private var learned: Set<String> { Set(learnedRaw.split(separator: ",").map(String.init)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenTitle(topic.title, subtitle: topic.subtitle)
                ForEach(Array(topic.lessons.enumerated()), id: \.element.id) { index, lesson in
                    NavigationLink {
                        CampusLessonView(lesson: lesson, learnedRaw: $learnedRaw)
                    } label: {
                        HStack(spacing: 16) {
                            Text("\(index + 1)")
                                .font(.title2.bold())
                                .foregroundStyle(learned.contains(lesson.id) ? AppTheme.onAccent : AppTheme.ink)
                                .frame(width: 52, height: 52)
                                .background(learned.contains(lesson.id) ? AppTheme.accent : AppTheme.fill, in: Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                Text(lesson.title)
                                    .font(.title3.bold())
                                    .foregroundStyle(AppTheme.ink)
                                    .multilineTextAlignment(.leading)
                                Text(learned.contains(lesson.id) ? "Learned · \(lesson.minutes) min" : "\(lesson.minutes) min read")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        .cardStyle(padding: 16)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .appScreen()
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CampusLessonView: View {
    let lesson: CampusLesson
    @Binding var learnedRaw: String
    @Environment(\.dismiss) private var dismiss

    private var isLearned: Bool { learnedRaw.split(separator: ",").contains { $0 == lesson.id } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenTitle(lesson.title, subtitle: "\(lesson.minutes) min read")
                ForEach(lesson.sections, id: \.heading) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.heading)
                            .font(.title2.bold())
                            .foregroundStyle(AppTheme.ink)
                        Text(section.body)
                            .font(.title3)
                            .foregroundStyle(AppTheme.ink)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Remember")
                        .font(.title2.bold())
                        .foregroundStyle(AppTheme.accent)
                    ForEach(lesson.takeaways, id: \.self) { line in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(AppTheme.accent)
                            Text(line)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppTheme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle(padding: 20)

                Button {
                    toggleLearned()
                    if isLearned { dismiss() }
                } label: {
                    Label(isLearned ? "Learned" : "Mark as learned", systemImage: isLearned ? "checkmark" : "graduationcap.fill")
                }
                .buttonStyle(.primary)
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .appScreen()
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggleLearned() {
        var set = Set(learnedRaw.split(separator: ",").map(String.init))
        if set.contains(lesson.id) { set.remove(lesson.id) } else { set.insert(lesson.id) }
        learnedRaw = set.sorted().joined(separator: ",")
    }
}
