import SwiftUI

/// The live window: ink, dark. At the top the elapsed time, the title of the call, its app and
/// language and the levels of the two tracks; in the middle the live transcript with the text
/// being recognised under it; on the right who is in the call and the notes; at the bottom the
/// waveform and the buttons.
struct LiveWindowView: View {
    let controller: RecordingViewController
    let recorder: Recorder

    @State private var noteDraft = ""

    private var state: LiveRecordingState { controller.state }
    private var call: Call? { state.call }
    private let teamsMeeting = TeamsMeetingController.shared
    private let identification = SpeakerIdentificationController.shared

    /// The title and the number of people of the meeting Teams shows; the title is left out when it
    /// is already the title of the call.
    private var meetingLine: String? {
        RecordingMeetingLine.text(meeting: teamsMeeting.meeting, callTitle: call?.displayTitle)
    }

    var body: some View {
        VStack(spacing: 0) {
            topRow
            HStack(alignment: .top, spacing: 24) {
                transcriptColumn
                sideColumn
            }
            .padding(.top, 20)
            bottomRow
                .padding(.top, 20)
        }
        .padding(.leading, 28)
        .padding(.trailing, 28)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .frame(minWidth: 900, minHeight: 600)
        .larpSurface(.ink)
        .ignoresSafeArea()
    }

    // MARK: Top row

    private var topRow: some View {
        HStack(spacing: 12) {
            // Room for the buttons of the window.
            Color.clear.frame(width: 56, height: 1)
            elapsedChip
            Text(call?.displayTitle ?? "")
                .font(LARPFont.inter(13, .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(subtitle)
                .font(LARPFont.inter(13))
                .foregroundStyle(LARPColor.textMuted)
                .lineLimit(1)
            if let meetingLine {
                Text(verbatim: meetingLine)
                    .font(LARPFont.inter(13))
                    .foregroundStyle(LARPColor.textMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            LevelBar(label: "Call", level: shownLevel(state.system))
            LevelBar(label: "Mic", level: shownLevel(state.microphone))
        }
        .frame(height: 32)
    }

    private var elapsedChip: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(recorder.isPaused ? LARPColor.textMuted : LARPColor.recording)
                .frame(width: 8, height: 8)
            Text(
                recorder.isPaused
                    ? LocalizedStringKey("IN PAUSA") : LocalizedStringKey("REC \(Recorder.formatElapsed(recorder.elapsedSeconds))")
            )
                .font(LARPFont.mono(12))
                .foregroundStyle(LiveWindowColor.chipText)
        }
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(LiveWindowColor.chipFill, in: Capsule())
        .accessibilityElement(children: .combine)
    }

    /// "· <call app> · <language>", or that there is no live transcription.
    private var subtitle: String {
        guard let call else { return "" }
        let app = call.callAppName ?? L10n.string("Manuale")
        let detail =
            state.isTranscribing
            ? ArchiveFormat.language(call.transcriptionLanguage)
            : L10n.string("Nessuna trascrizione dal vivo")
        return "· \(app) · \(detail)"
    }

    // MARK: Transcript

    private var transcriptColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(rows, id: \.line.id) { row in
                        LiveLineRow(line: row.line, isBookmarked: isBookmarked(row.line), teamsName: row.teamsName)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // Starts at the newest line and follows it, unless the user scrolled up.
            .defaultScrollAnchor(.bottom)
            .frame(maxHeight: .infinity)
            recognisingText
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var lines: [TranscriptLine] {
        call?.sortedLines ?? []
    }

    /// Each line with the name Teams marked as speaking when it started, for a line of "Altri" while
    /// Teams shows the meeting and "Identifica i parlanti" is on.
    private var rows: [(line: TranscriptLine, teamsName: String?)] {
        let spans = showsTeamsNames ? (call?.speakerTimeline ?? []) : []
        return lines.map { line in
            guard showsTeamsNames, line.speakerKind == .others else { return (line, nil) }
            return (line, LiveTeamsNames.speaker(at: line.start, spans: spans, current: teamsMeeting.speaker))
        }
    }

    /// Teams shows the meeting of the call and "Identifica i parlanti" is on.
    private var showsTeamsNames: Bool {
        identification.isOn && teamsMeeting.meeting != nil
    }

    /// The people Teams shows in the meeting, when the window shows them in place of "Altri".
    private var teamsPeople: [LiveTeamsNames.Member] {
        guard showsTeamsNames else { return [] }
        return LiveTeamsNames.members(people: teamsMeeting.people, speaker: teamsMeeting.speaker)
    }

    /// Who says the text being recognised: the name Teams marks as speaking for "Altri", when it
    /// marks one.
    private var recognisingName: String {
        guard let recognising = state.recognising else { return "" }
        if recognising.speaker == .others, showsTeamsNames, let name = teamsMeeting.speaker {
            return name
        }
        return recognising.speaker.displayName
    }

    private func isBookmarked(_ line: TranscriptLine) -> Bool {
        LiveTranscriptRules.isBookmarked(
            start: line.start, end: line.end, bookmarkTimes: call?.bookmarks.map(\.time) ?? [])
    }

    /// The text being recognised, large, with who says it; its last words are dimmed.
    @ViewBuilder
    private var recognisingText: some View {
        if let recognising = state.recognising {
            let parts = LiveTranscriptRules.splitRecognised(recognising.text)
            VStack(alignment: .leading, spacing: 8) {
                Text("\(recognisingName.uppercased()) · STA PARLANDO")
                    .font(LARPFont.mono(11))
                    .tracking(0.08 * 11)
                    .foregroundStyle(LARPColor.lime)
                (Text(parts.steady).foregroundStyle(.white)
                    + Text(parts.tail).foregroundStyle(LiveWindowColor.recognisedTail))
                    .font(LARPFont.display(32, .semibold))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Side column

    private var sideColumn: some View {
        VStack(spacing: 16) {
            inTheCallCard
            notesCard
        }
        .frame(width: 200)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var inTheCallCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nella call")
                .font(LARPFont.display(16, .semibold))
                .foregroundStyle(.white)
            SpeakerRow(kind: .me, isSpeaking: shownLevel(state.microphone).isSpeaking)
            if teamsPeople.isEmpty {
                SpeakerRow(kind: .others, isSpeaking: shownLevel(state.system).isSpeaking)
            } else {
                ForEach(Array(teamsPeople.enumerated()), id: \.offset) { index, person in
                    TeamsPersonRow(name: person.name, number: index + 1, isSpeaking: person.isSpeaking)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .larpCard(.darkRaised, padding: 16)
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Le tue note")
                .font(LARPFont.display(16, .semibold))
                .foregroundStyle(.white)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(call?.sortedNotes ?? []) { note in
                        NoteRow(note: note)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)
            noteField
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .larpCard(.darkRaised, padding: 16)
    }

    private var noteField: some View {
        TextField(
            text: $noteDraft,
            prompt: Text("Scrivi una nota…").foregroundStyle(LARPColor.textMuted)
        ) { EmptyView() }
        .textFieldStyle(.plain)
        .font(LARPFont.inter(13))
        .foregroundStyle(.white)
        .onSubmit {
            controller.addNote(noteDraft)
            noteDraft = ""
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(LARPColor.darkCard, in: RoundedRectangle(cornerRadius: 10))
        .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(LARPColor.darkBorder, lineWidth: 1) }
    }

    // MARK: Bottom row

    private var bottomRow: some View {
        HStack(spacing: 12) {
            GeometryReader { proxy in
                WaveformBars(
                    bars: waveform(width: proxy.size.width), barWidth: Self.barWidth, gap: Self.barGap)
            }
            .frame(height: 40)
            Button(action: controller.addBookmark) {
                HStack(spacing: 8) {
                    Text("Segnalibro")
                    ShortcutHint(.bookmark)
                }
            }
            .buttonStyle(.larp(.outlineOnDark))
            Button(action: controller.togglePause) {
                Text(LocalizedStringKey(recorder.isPaused ? "Riprendi" : "Pausa"))
            }
            .buttonStyle(.larp(.outlineOnDark))
            Button(action: controller.stopRecording) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2).fill(LARPColor.ink).frame(width: 10, height: 10)
                    Text("Ferma")
                }
            }
            .buttonStyle(.larp(.primary))
        }
    }

    /// The last minute of the waveform is lime, the older seconds `#3A3C36`.
    private static let accentSeconds = 60
    private static let barWidth: CGFloat = 3
    private static let barGap: CGFloat = 2

    /// The bars of the seconds that fit in `width`, the newest on the right; flat while paused.
    private func waveform(width: CGFloat) -> [WaveformBars.Bar] {
        let count = max(1, Int((width + Self.barGap) / (Self.barWidth + Self.barGap)))
        let levels = recorder.isPaused ? [] : state.secondBars
        let shown = Array(levels.suffix(count))
        let padded = Array(repeating: 0, count: count - shown.count) + shown
        return padded.enumerated().map { index, level in
            WaveformBars.Bar(
                level: level, color: index >= count - Self.accentSeconds ? LARPColor.lime : LARPColor.darkBorder)
        }
    }

    /// While paused every level is empty.
    private func shownLevel(_ level: TrackLevel) -> TrackLevel {
        recorder.isPaused ? .silent : level
    }
}

/// Colours of the live window that are not in the shared palette.
private enum LiveWindowColor {
    /// The chip "REC <time>".
    static let chipFill = Color(hex: 0x2A1512)
    static let chipText = Color(hex: 0xFF8672)
    /// The last words of the text being recognised.
    static let recognisedTail = Color(hex: 0x8A8D82)
}

/// "Call" or "Mic" and a 56 × 4 px bar, lime on `#3A3C36`.
private struct LevelBar: View {
    let label: LocalizedStringKey
    let level: TrackLevel

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(LARPFont.inter(12))
                .foregroundStyle(LARPColor.textMuted)
            ZStack(alignment: .leading) {
                Capsule().fill(LARPColor.darkBorder)
                Capsule().fill(LARPColor.lime).frame(width: 56 * level.level)
            }
            .frame(width: 56, height: 4)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A final line: "● <SPEAKER> · <time>" over its text; "· SEGNALIBRO" when a bookmark marks it.
private struct LiveLineRow: View {
    let line: TranscriptLine
    let isBookmarked: Bool
    /// The name Teams marked as speaking at the start of the line, for a line of "Altri".
    var teamsName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(line.speakerColor(onDark: true)).frame(width: 8, height: 8)
                Text(eyebrow)
                    .font(LARPFont.mono(11))
                    .tracking(0.08 * 11)
                    .foregroundStyle(LARPColor.textMuted)
            }
            Text(line.text)
                .font(LARPFont.inter(15))
                .foregroundStyle(LARPColor.textOnDark)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var eyebrow: String {
        let name = (teamsName ?? line.speakerName).uppercased()
        let base = "\(name) · \(Recorder.formatElapsed(Int(line.start)))"
        return isBookmarked ? base + " · " + L10n.string("SEGNALIBRO") : base
    }
}

/// A person Teams shows in the meeting, in "Nella call": the avatar, the name and a small lime
/// glyph while Teams marks them as speaking.
private struct TeamsPersonRow: View {
    let name: String
    let number: Int
    let isSpeaking: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(String(name.prefix(1)).uppercased())
                .font(LARPFont.inter(12, .semibold))
                .foregroundStyle(SpeakerPalette.initialColor(kind: .participant, onDark: true))
                .frame(width: 28, height: 28)
                .background(SpeakerPalette.color(kind: .participant, participantNumber: number, onDark: true), in: Circle())
            Text(verbatim: name)
                .font(LARPFont.inter(13, .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 0)
            if isSpeaking {
                Image(systemName: "waveform")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LARPColor.lime)
                    .accessibilityLabel(Text("Sta parlando"))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A row of "Nella call": the avatar, the name and a small lime level glyph while it speaks.
private struct SpeakerRow: View {
    let kind: SpeakerKind
    let isSpeaking: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(String(kind.displayName.prefix(1)))
                .font(LARPFont.inter(12, .semibold))
                .foregroundStyle(SpeakerPalette.initialColor(kind: kind, onDark: true))
                .frame(width: 28, height: 28)
                .background(SpeakerPalette.color(kind: kind, participantNumber: nil, onDark: true), in: Circle())
            Text(kind.displayName)
                .font(LARPFont.inter(13, .medium))
                .foregroundStyle(.white)
            Spacer(minLength: 0)
            if isSpeaking {
                Image(systemName: "waveform")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LARPColor.lime)
                    .accessibilityLabel(Text("Sta parlando"))
            }
        }
    }
}

/// A note with its time in JetBrains Mono.
private struct NoteRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let time = note.time {
                Text(Recorder.formatElapsed(Int(time)))
                    .font(LARPFont.mono(11))
                    .foregroundStyle(LARPColor.textMuted)
            }
            Text(note.text)
                .font(LARPFont.inter(13))
                .foregroundStyle(LARPColor.textOnDark)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
