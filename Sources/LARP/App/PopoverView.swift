import AppKit
import SwiftUI

/// The popover under the menu bar icon (`requirements/ui#recorder`): 340 px wide, ink, radius 18, 14 px
/// padding, dark. From the top: the LARP mark with "LARP" and the state of the recorder, the card of
/// the state, the audio and microphone rows and, after a divider, "Apri archivio", "Impostazioni" and
/// "Esci".
struct PopoverView: View {
    /// Closes the popover.
    let close: () -> Void
    /// Tells the panel the size of the content, when it changes.
    let resize: (CGSize) -> Void

    private let recorder = Recorder.shared
    private let autoRecording = AutoRecordingController.shared
    private let live = RecordingViewController.shared.state
    private let calendar = CalendarAccessController.shared
    private let teamsAccess = TeamsAccessController.shared
    private let teamsMeeting = TeamsMeetingController.shared
    /// "Prossime": at most three meetings of the rest of the day.
    @State private var upcoming: [UpcomingMeeting] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            stateCard
            VStack(spacing: 0) {
                PopoverRow(title: "Audio della call") {
                    Text(verbatim: callAppName ?? "—")
                        .font(LARPFont.inter(13))
                        .foregroundStyle(LARPColor.textMuted)
                }
                LARPDivider()
                PopoverRow(title: "Microfono") {
                    MicrophoneChoiceBox(minWidth: 180)
                }
                LARPDivider()
                PopoverRow(title: "Registra automaticamente le call rilevate") {
                    // `user.TURN_ON_AUTO_RECORDING` / `user.TURN_OFF_AUTO_RECORDING`.
                    LARPSwitch(
                        isOn: Binding(
                            get: { autoRecording.isOn },
                            set: { $0 ? autoRecording.turnOn() : autoRecording.turnOff() }
                        )
                    )
                    .accessibilityLabel("Registra automaticamente le call rilevate")
                }
            }
            .padding(.horizontal, 4)
            if calendar.isConnected, !upcoming.isEmpty {
                upcomingMeetings
            }
            if teamsAccess.mustBeAllowedAgain {
                allowTeamsAgain
            }
            LARPDivider()
            footer
        }
        .padding(14)
        .frame(width: 340)
        .background(LARPColor.ink, in: RoundedRectangle(cornerRadius: 18))
        .larpAppearance(dark: true)
        .tint(LARPColor.lime)
        .larpEnvironment()
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { resize($0) }
        // The next meetings are read again every time the popover opens.
        .onAppear { upcoming = calendar.upcomingMeetings() }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            LarpWordmark()
            Spacer(minLength: 8)
            Text(stateText)
                .font(LARPFont.inter(13))
                .foregroundStyle(LARPColor.textMuted)
        }
        .padding(.horizontal, 4)
    }

    /// "Pronto quando vuoi" (also after "Non questa"), "Call rilevata", "In registrazione" or "In pausa".
    private var stateText: LocalizedStringKey {
        switch recorder.state {
        case .idle, .proposalDismissed: "Pronto quando vuoi"
        case .proposing: "Call rilevata"
        case .recording: recorder.isPaused ? "In pausa" : "In registrazione"
        }
    }

    private var pauseTitle: LocalizedStringKey {
        recorder.isPaused ? "Riprendi" : "Pausa"
    }

    private var callAppName: String? {
        switch recorder.state {
        case .idle, .proposalDismissed: nil
        case .proposing(let app): app.name
        case .recording(let recording): recording.callApp?.name
        }
    }

    // MARK: State card

    /// The card of the state, `#1D1F1A`, radius 14, 16 px padding.
    @ViewBuilder
    private var stateCard: some View {
        Group {
            switch recorder.state {
            case .idle, .proposalDismissed: idleCard
            case .proposing(let app):
                ProposalCard(
                    appName: app.name,
                    meeting: recorder.proposalMeeting,
                    // `user.ACCEPT_PROPOSAL`.
                    accept: { Task { await recorder.acceptProposal() } },
                    // `user.DISMISS_PROPOSAL`.
                    dismiss: { recorder.dismissProposal() })
            case .recording: recordingCard
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(LARPColor.darkRaised, in: RoundedRectangle(cornerRadius: 14))
    }

    private var idleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Registrazione manuale")
            Text("Nessuna call in corso")
                .font(LARPFont.display(22, .semibold))
                .tracking(-0.01 * 22)
                .foregroundStyle(.white)
            // `user.START_RECORDING`: a recording tied to no call app.
            Button {
                Task { await recorder.startRecording() }
            } label: {
                HStack(spacing: 10) {
                    Text("Registra")
                    Spacer(minLength: 0)
                    if let keys = ShortcutsController.shared.display(for: .record) {
                        ShortcutKeys(text: keys, style: .plain(LARPColor.ink))
                    }
                }
            }
            .buttonStyle(LARPButtonStyle(kind: .primary, fullWidth: true))
            .padding(.top, 6)
        }
    }

    private var recordingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(recorder.isPaused ? LARPColor.textMuted : LARPColor.recording)
                    .frame(width: 8, height: 8)
                Eyebrow(stateText)
            }
            Text(verbatim: live.call?.displayTitle ?? "")
                .font(LARPFont.display(22, .semibold))
                .tracking(-0.01 * 22)
                .foregroundStyle(.white)
                .lineLimit(2)
            if let meetingLine {
                Text(verbatim: meetingLine)
                    .font(LARPFont.inter(13))
                    .foregroundStyle(LARPColor.textMuted)
                    .lineLimit(2)
            }
            Text(verbatim: Recorder.formatElapsed(recorder.elapsedSeconds))
                .font(LARPFont.mono(13))
                .foregroundStyle(LARPColor.textOnDark)
            HStack(spacing: 8) {
                // `user.PAUSE_RECORDING` / `user.RESUME_RECORDING`.
                Button(pauseTitle) { recorder.togglePause() }
                    .buttonStyle(.larp(.outlineOnDark))
                // `user.STOP_RECORDING`.
                Button {
                    recorder.stopRecording()
                } label: {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2).fill(LARPColor.ink).frame(width: 10, height: 10)
                        Text("Ferma registrazione")
                    }
                }
                .buttonStyle(LARPButtonStyle(kind: .white, fullWidth: true))
            }
            .padding(.top, 6)
            // `user.OPEN_LIVE_WINDOW`.
            Button("Apri finestra dal vivo") {
                close()
                recorder.openLiveWindow()
            }
            .buttonStyle(.larpLink)
            .padding(.top, 4)
        }
    }

    /// The title and the number of people of the meeting Teams shows during a recording; the title
    /// is left out when it is already the title of the call.
    private var meetingLine: String? {
        RecordingMeetingLine.text(meeting: teamsMeeting.meeting, callTitle: live.call?.displayTitle)
    }

    // MARK: Next meetings and Teams

    /// While the calendar is connected: the eyebrow "Prossime" and one row per meeting, with its
    /// start time in JetBrains Mono lime, its title in 13 px `#E9EAE3` and its call app on the
    /// right in `#A3A69B`.
    private var upcomingMeetings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Prossime")
            ForEach(upcoming) { meeting in
                HStack(spacing: 10) {
                    Text(verbatim: ArchiveFormat.time(meeting.start))
                        .font(LARPFont.mono(12))
                        .foregroundStyle(LARPColor.lime)
                    Text(verbatim: meeting.title)
                        .font(LARPFont.inter(13))
                        .foregroundStyle(LARPColor.textOnDark)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(verbatim: meeting.appName)
                        .font(LARPFont.inter(12))
                        .foregroundStyle(LARPColor.textMuted)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    /// Teams access was granted to an earlier version and is missing now: the row opens the
    /// settings (`user.OPEN_SETTINGS`), where "Consenti" asks for it again.
    private var allowTeamsAgain: some View {
        Button {
            close()
            MainWindowController.shared.openSettings()
        } label: {
            Text("Consenti di nuovo l'accesso a Teams")
                .font(LARPFont.inter(13))
                .foregroundStyle(LARPColor.peach)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
        }
        .buttonStyle(.larpPlain)
        .padding(.horizontal, 4)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 16) {
            // `user.OPEN_WINDOW`.
            FooterButton(title: "Apri archivio") {
                close()
                MainWindowController.shared.openLibrary()
            }
            Spacer(minLength: 8)
            // `user.OPEN_SETTINGS`.
            FooterButton(title: "Impostazioni") {
                close()
                MainWindowController.shared.openSettings()
            }
            FooterButton(title: "Esci") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 4)
    }
}

/// A row of the popover: its title in 13 px and, on the right, its value or control.
private struct PopoverRow<Trailing: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(LARPFont.inter(13))
                .foregroundStyle(LARPColor.textOnDark)
            Spacer(minLength: 8)
            trailing
        }
        .frame(minHeight: 44)
    }
}

/// A button of the footer: 13 px `#E9EAE3`.
private struct FooterButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(LARPFont.inter(13))
                .foregroundStyle(LARPColor.textOnDark)
                .padding(.vertical, 4)
        }
        .buttonStyle(.larpPlain)
    }
}
