import SwiftData
import SwiftUI
import WatchKit

/// §16: "The morning check-in belongs on the wrist too. Four taps." One
/// question per screen, five big buttons, the fourth tap saves through the
/// same CheckInStore the phone uses (one row per day, §14).
struct WatchCheckInView: View {
    let athlete: Athlete
    let onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var step = 0
    @State private var answers: [Int] = []

    private let questions: [(title: String, low: String, high: String)] = [
        ("How did you sleep?", "Poorly", "Great"),
        ("How sore are you?", "Not at all", "Very"),
        ("Your energy?", "Drained", "Buzzing"),
        ("Stress / school?", "Calm", "Stressed"),
    ]

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? Color.white : Color.white.opacity(0.2))
                        .frame(height: 3)
                }
            }
            Text(questions[step].title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        answer(value)
                    } label: {
                        Text("\(value)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(.plain)
                    .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityLabel("\(questions[step].title) \(value) of 5")
                }
            }
            HStack {
                Text(questions[step].low)
                Spacer()
                Text(questions[step].high)
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
    }

    private func answer(_ value: Int) {
        answers.append(value)
        WKInterfaceDevice.current().play(.click)
        if answers.count == 4 {
            _ = try? CheckInStore(modelContext: modelContext).submit(
                athlete: athlete, sleepQuality: answers[0], soreness: answers[1], energy: answers[2], stress: answers[3]
            )
            WKInterfaceDevice.current().play(.success)
            onDone()
        } else {
            step += 1
        }
    }
}
