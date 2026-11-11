import SwiftUI

/// The row of speaker chips on the page of a call: one chip per speaker ("Io" only when it has lines,
/// and every participant) with its avatar, its name and its share of the speaking time, the largest
/// first, and the underlined link "Rinomina parlanti".
///
/// A click on the chip of a participant renames it (`user.RENAME_PARTICIPANT`): the chip becomes a
/// field, under which the names offered are listed as chips to click, filtered by what is typed; Return
/// confirms and Esc cancels. "Rinomina parlanti" puts the first participant chip into renaming. A
/// participant can be renamed only while the call is ready.
struct SpeakerChipsRow: View {
    let call: Call
    /// The number of the participant being renamed, `nil` when none is.
    @Binding var renaming: Int?
    @Environment(CallLifecycle.self) private var lifecycle
    @State private var draft = ""

    var body: some View {
        let speakers = CallSpeakers.speakers(of: call)
        if !speakers.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                FlowLayout(spacing: 8, rowSpacing: 8) {
                    ForEach(speakers) { speaker in
                        if speaker.participantNumber != nil, speaker.participantNumber == renaming {
                            SpeakerRenameChip(speaker: speaker, name: $draft, confirm: confirm, cancel: cancel)
                        } else {
                            SpeakerChip(speaker: speaker, rename: canRename ? { startRenaming(speaker) } : nil)
                        }
                    }
                    if canRename, let first = speakers.first(where: { $0.participantNumber != nil }) {
                        Button("Rinomina parlanti") { startRenaming(first) }
                            .buttonStyle(.larpLink)
                            .font(LARPFont.inter(12))
                    }
                }
                suggestions
            }
            // The call is not ready any more: no participant can be renamed.
            .onChange(of: canRename) { _, can in if !can { renaming = nil } }
            .onChange(of: renaming) { _, number in
                if let number { draft = participant(number)?.name ?? "" }
            }
            .onAppear {
                if let number = renaming { draft = participant(number)?.name ?? "" }
            }
        }
    }

    /// The names the field offers: those kept with the call from Teams and the calendar that no
    /// other participant has, filtered by what is typed.
    @ViewBuilder
    private var suggestions: some View {
        if let number = renaming, let participant = participant(number) {
            let names = ParticipantNameSuggestions.filtered(
                lifecycle.offeredNames(for: participant, in: call), typed: draft)
            if !names.isEmpty {
                FlowLayout(spacing: 8, rowSpacing: 8) {
                    ForEach(names, id: \.self) { name in
                        LARPChip(title: LocalizedStringKey(name), isSelected: false) {
                            draft = name
                            confirm()
                        }
                    }
                }
            }
        }
    }

    private var canRename: Bool {
        CallStateMachine.target(from: call.state, on: .renameParticipant) != nil
    }

    private func participant(_ number: Int) -> Participant? {
        call.participants.first { $0.number == number }
    }

    private func startRenaming(_ speaker: CallSpeaker) {
        guard let number = speaker.participantNumber else { return }
        draft = participant(number)?.name ?? ""
        renaming = number
    }

    /// `user.RENAME_PARTICIPANT`: the new name goes to the call; an empty one restores the default.
    private func confirm() {
        if let number = renaming, let participant = participant(number) {
            lifecycle.renameParticipant(participant, to: draft)
        }
        renaming = nil
    }

    private func cancel() {
        renaming = nil
    }
}

/// The chip of a speaker: its avatar, its name and its share of the speaking time in JetBrains Mono
/// 11 px `#5A5D55`; 32 px high, radius 16, white with a `#E4E4DC` border. The chip of a participant
/// renames it when clicked.
struct SpeakerChip: View {
    let speaker: CallSpeaker
    /// `nil` for a speaker that cannot be renamed.
    let rename: (() -> Void)?

    var body: some View {
        if let rename, speaker.participantNumber != nil {
            Button(action: rename) { content }
                .buttonStyle(.larpPlain)
        } else {
            content
        }
    }

    private var content: some View {
        HStack(spacing: 8) {
            LARPAvatar(
                initial: speaker.initial, kind: speaker.kind, participantNumber: speaker.participantNumber,
                ring: LARPColor.white, size: 22)
            Text(verbatim: speaker.name)
                .font(LARPFont.inter(13, .medium))
                .foregroundStyle(LARPColor.ink)
            Text(verbatim: "\(speaker.percent)%")
                .font(LARPFont.mono(11))
                .foregroundStyle(LARPColor.textSecondary)
        }
        .padding(.leading, 5)
        .padding(.trailing, 12)
        .frame(height: 32)
        .background(LARPColor.white, in: Capsule())
        .overlay { Capsule().strokeBorder(LARPColor.border, lineWidth: 1) }
    }
}

/// The chip of a participant being renamed: its avatar and a text field in place of its name and
/// share, focused when it appears; Return confirms and Esc cancels.
private struct SpeakerRenameChip: View {
    let speaker: CallSpeaker
    @Binding var name: String
    let confirm: () -> Void
    let cancel: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            LARPAvatar(
                initial: speaker.initial, kind: speaker.kind, participantNumber: speaker.participantNumber,
                ring: LARPColor.white, size: 22)
            TextField(text: $name, prompt: Text(verbatim: speaker.name).foregroundStyle(LARPColor.textSecondary)) {
                EmptyView()
            }
            .textFieldStyle(.plain)
            .font(LARPFont.inter(13, .medium))
            .foregroundStyle(LARPColor.ink)
            .focused($isFocused)
            .onSubmit(confirm)
            .onExitCommand(perform: cancel)
            .frame(width: 160)
        }
        .padding(.leading, 5)
        .padding(.trailing, 12)
        .frame(height: 32)
        .background(LARPColor.white, in: Capsule())
        .overlay { Capsule().strokeBorder(LARPColor.ink, lineWidth: 2) }
        .onAppear { isFocused = true }
    }
}
