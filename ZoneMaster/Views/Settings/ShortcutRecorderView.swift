import SwiftUI
import Carbon.HIToolbox

/// A view that records a keyboard shortcut when clicked.
/// User clicks the field, presses a key combo, and it's captured.
struct ShortcutRecorderView: View {
    let label: String
    @Binding var shortcut: KeyboardShortcut

    @State private var isRecording = false

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 180, alignment: .leading)

            Button(action: { isRecording.toggle() }) {
                Text(isRecording ? "Press keys..." : (shortcut.displayString.isEmpty ? "Click to set" : shortcut.displayString))
                    .frame(width: 120)
                    .padding(.vertical, 4)
                    .background(isRecording ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.1))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isRecording ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .onKeyPress { keyPress in
                guard isRecording else { return .ignored }

                // Build display string from modifiers + key
                var display = ""
                if keyPress.modifiers.contains(.control) { display += "⌃" }
                if keyPress.modifiers.contains(.option) { display += "⌥" }
                if keyPress.modifiers.contains(.shift) { display += "⇧" }
                if keyPress.modifiers.contains(.command) { display += "⌘" }
                display += keyPress.characters.uppercased()

                shortcut = KeyboardShortcut(
                    keyCode: 0, // Will be resolved at registration time
                    modifiers: keyPress.modifiers.rawValue,
                    displayString: display
                )

                isRecording = false
                return .handled
            }

            if !shortcut.displayString.isEmpty {
                Button(action: {
                    shortcut = .empty
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Clear shortcut")
            }
        }
    }
}
