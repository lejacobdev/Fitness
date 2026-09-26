import SwiftUI

/// Me → My Development Goals: up to three goals the training leans towards.
struct StrugglesSheet: View {
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selected = Struggles.selected

    var body: some View {
        StepScaffold(
            title: "My Development Goals",
            subtitle: "Pick up to \(Struggles.maximum). Your training leans towards them.",
            buttonTitle: "Save", onBack: { dismiss() },
            onContinue: {
                Struggles.selected = selected
                onSaved()
                dismiss()
            }
        ) {
            VStack(spacing: 10) {
                ForEach(Struggle.allCases) { struggle in
                    let isOn = selected.contains(struggle)
                    Button {
                        if isOn {
                            selected.removeAll { $0 == struggle }
                        } else if selected.count < Struggles.maximum {
                            selected.append(struggle)
                        }
                    } label: {
                        OptionRow(title: struggle.title, subtitle: isOn ? struggle.whatChanges : nil,
                                  systemImage: struggle.systemImage, isSelected: isOn)
                    }
                    .buttonStyle(.plain)
                    .opacity(!isOn && selected.count >= Struggles.maximum ? 0.45 : 1)
                }
            }
            if selected.count >= Struggles.maximum {
                Text("That's \(Struggles.maximum) — tap one to swap it. Focusing on a few things works better than on everything.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }
}
