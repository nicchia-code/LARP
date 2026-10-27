import SwiftData
import SwiftUI

/// The selected call: editable title, date, duration, call app, playback controls and transcript.
struct CallDetailView: View {
    let call: Call
    let playback: PlaybackController

    @Environment(CallLifecycle.self) private var lifecycle
    @State private var titleDraft: String
    @FocusState private var titleIsFocused: Bool
    @State private var participantToRename: Participant?
    @State private var participantDraft = ""

    init(call: Call, playback: PlaybackController) {
        self.call = call
        self.playback = playback
        _titleDraft = State(initialValue: call.title ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if call.state != .recording {
                PlaybackControlsView(playback: playback)
            }
            Divider()
            transcript
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { show() }
        .onChange(of: call.state) { show() }
        .onChange(of: call.lines.count) { updateTimeline() }
        .onChange(of: call.title) { titleDraft = call.title ?? "" }
        .alert(
            "Rinomina partecipante",
            isPresented: Binding(
                get: { participantToRename != nil },
                set: { if !$0 { participantToRename = nil } }
            )
        ) {
            TextField("Nome", text: $participantDraft)
            Button("Rinomina") {
                if let participant = participantToRename {
                    lifecycle.renameParticipant(participant, to: participantDraft)
                }
                participantToRename = nil
            }
            Button("Annulla", role: .cancel) { participantToRename = nil }
        } message: {
            Text("Il nuovo nome vale in tutta la trascrizione di questa call. Un nome vuoto ripristina quello predefinito.")
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Titolo", text: $titleDraft, prompt: Text(call.displayTitle))
                .textFieldStyle(.plain)
                .font(.title2.bold())
                .focused($titleIsFocused)
                .disabled(!lifecycle.canRename(call))
                .onSubmit(commitTitle)
                .onChange(of: titleIsFocused) { _, isFocused in
                    if !isFocused { commitTitle() }
                }
            HStack(spacing: 6) {
                Text(ArchiveFormat.dayAndTime(call.startedAt))
                if call.state != .recording {
                    Text("·")
                    Text(ArchiveFormat.duration(call.duration)).monospacedDigit()
                }
                if let app = call.callAppName {
                    Text("·")
                    Text(app)
                }
                if let status = lifecycle.statusLabel(of: call) {
                    Text("·")
                    Text(status).foregroundStyle(.orange)
                }
            }
            .foregroundStyle(.secondary)
        }
    }

    private func commitTitle() {
        guard titleDraft != (call.title ?? "") else { return }
        lifecycle.renameCall(call, to: titleDraft)
        titleDraft = call.title ?? ""
    }

    // MARK: Transcript

    @ViewBuilder
    private var transcript: some View {
        let lines = call.sortedLines
        if lines.isEmpty {
            ContentUnavailableView(
                call.state == .ready ? "Nessuna trascrizione" : "Trascrizione non ancora disponibile",
                systemImage: "text.alignleft"
            )
        } else {
            TranscriptView(lines: lines, playback: playback) { participant in
                participantDraft = participant.name ?? ""
                participantToRename = participant
            }
        }
    }

    /// Loads the audio of the call into the playback (stopping any other call's) and its lines' times.
    private func show() {
        playback.show(call)
        updateTimeline()
    }

    private func updateTimeline() {
        playback.setTimeline(call.sortedLines.map { LineTiming(start: $0.start, end: $0.end) })
    }
}
