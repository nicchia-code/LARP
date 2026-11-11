import SwiftUI

/// The names a rename field offers while a name is typed: the offered ones whose text, without case
/// and accents, holds what is typed; all of them while nothing is typed.
enum ParticipantNameSuggestions {
    static func filtered(_ offered: [String], typed: String) -> [String] {
        let needle = TeamsText.fold(typed)
        guard !needle.isEmpty else { return offered }
        return offered.filter { TeamsText.fold($0).contains(needle) }
    }
}

/// The rename field of a participant: the field, under it the names offered as chips to click,
/// filtered by what is typed, and "Annulla" and "Rinomina" (`user.RENAME_PARTICIPANT`).
struct ParticipantRenameView: View {
    @Binding var name: String
    /// The names kept with the call from Teams and the calendar that no other participant has;
    /// empty while "Identifica i parlanti" is off.
    let offered: [String]
    let rename: () -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rinomina partecipante")
                .font(LARPFont.display(20, .semibold))
                .tracking(-0.01 * 20)
                .foregroundStyle(LARPColor.ink)
            LARPTextField(prompt: "Nome", text: $name, onSubmit: rename)
            let suggestions = ParticipantNameSuggestions.filtered(offered, typed: name)
            if !suggestions.isEmpty {
                FlowLayout(spacing: 8, rowSpacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        LARPChip(title: LocalizedStringKey(suggestion), isSelected: false) {
                            name = suggestion
                        }
                    }
                }
            }
            Text("Il nuovo nome vale in tutta la trascrizione di questa call. Un nome vuoto ripristina quello predefinito.")
                .font(LARPFont.inter(12))
                .foregroundStyle(LARPColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Button("Annulla", action: cancel)
                    .buttonStyle(.larp(.outline))
                    .keyboardShortcut(.cancelAction)
                Button("Rinomina", action: rename)
                    .buttonStyle(.larp(.dark))
            }
        }
        .padding(24)
        .frame(width: 420)
        .larpSurface(.paper)
        .larpEnvironment()
    }
}
