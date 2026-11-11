import SwiftUI

/// The **Esportazione e integrazioni** section of the settings page: the Markdown folder, the calendar
/// and Microsoft Teams, each with the state of its access and the button that changes it.
struct IntegrationsSettingsCard: View {
    var body: some View {
        SettingsCard(title: "Esportazione e integrazioni") {
            MarkdownFolderSettingsRow()
            CalendarSettingsRow()
            TeamsSettingsRow()
        }
    }
}

/// The row "Calendario": "Collegato · dà il nome alle registrazioni e indica chi c'era", "Non
/// collegato" or "Accesso negato in Impostazioni di Sistema", and the outline button "Collega" or
/// "Scollega".
struct CalendarSettingsRow: View {
    private let calendar: CalendarAccessController

    init(calendar: CalendarAccessController = .shared) {
        self.calendar = calendar
    }

    var body: some View {
        let explanation: LocalizedStringKey =
            switch calendar.state {
            case .connected: "Collegato · dà il nome alle registrazioni e indica chi c'era"
            case .notConnected: "Non collegato"
            case .refused: "Accesso negato in Impostazioni di Sistema"
            }
        SettingsRow("Calendario", explanation: explanation) {
            if calendar.state == .connected {
                // `user.DISCONNECT_CALENDAR`.
                Button("Scollega") { calendar.disconnect() }
                    .buttonStyle(.larp(.outline))
            } else {
                // `user.CONNECT_CALENDAR`: macOS asks the first time; when the access was refused
                // the calendars pane of System Settings opens.
                Button("Collega") { Task { await calendar.connect() } }
                    .buttonStyle(.larp(.outline))
                    .disabled(calendar.isAsking)
            }
        }
    }
}

/// The row "Microsoft Teams": what LARP reads and, on the right, "Consenti" (dark), "In attesa…"
/// while the Accessibility permission is awaited, or the lime chip "✓ Consentito". When the
/// permission was lost after an update the explanation says it must be allowed again, in `#B42A18`.
struct TeamsSettingsRow: View {
    private let teams: TeamsAccessController

    init(teams: TeamsAccessController = .shared) {
        self.teams = teams
    }

    var body: some View {
        let mustBeAllowedAgain = teams.mustBeAllowedAgain
        let explanation: LocalizedStringKey =
            mustBeAllowedAgain
            ? "Da consentire di nuovo dopo l'aggiornamento"
            : "Titolo della riunione, partecipanti e chi parla, letti con l'Accessibilità; Teams usa un po' più di processore"
        SettingsRow("Microsoft Teams", explanation: explanation) {
            switch teams.state {
            case .notAllowed:
                // `user.ALLOW_TEAMS_ACCESS`.
                Button("Consenti") { teams.allowTeamsAccess() }
                    .buttonStyle(.larp(.dark))
            case .awaitingPermission:
                Text("In attesa…")
                    .font(LARPFont.inter(12))
                    .foregroundStyle(LARPColor.textSecondary)
            case .allowed:
                LARPStatusChip(text: "✓ " + L10n.string("Consentito"), kind: .done)
            }
        }
        .explanationTint(mustBeAllowedAgain ? LARPColor.destructive : LARPColor.textSecondary)
    }
}

/// The row "Cartella Markdown": a switch and "Salva ogni sintesi e trascrizione come file .md"; while it
/// is on, the path of the folder, the outline button "Cambia" and, after a failed write and until one
/// succeeds, "Impossibile scrivere nella cartella" in `#B42A18`.
struct MarkdownFolderSettingsRow: View {
    private let folder: MarkdownFolderController

    init(folder: MarkdownFolderController = .shared) {
        self.folder = folder
    }

    var body: some View {
        SettingsRow("Cartella Markdown", explanation: "Salva ogni sintesi e trascrizione come file .md") {
            LARPSwitch(
                isOn: Binding(
                    get: { folder.isOn },
                    // `user.TURN_ON_MARKDOWN_FOLDER` opens the choice of the folder, which when
                    // cancelled leaves the switch off; `user.TURN_OFF_MARKDOWN_FOLDER`.
                    set: { isOn in
                        if isOn {
                            Task { await folder.turnOn() }
                        } else {
                            folder.turnOff()
                        }
                    }
                )
            )
            .accessibilityLabel("Cartella Markdown")
        } below: {
            if let path = folder.folderPath {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Text(verbatim: (path as NSString).abbreviatingWithTildeInPath)
                            .font(LARPFont.mono(11))
                            .foregroundStyle(LARPColor.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        // `user.CHOOSE_MARKDOWN_FOLDER`.
                        Button("Cambia") { Task { await folder.chooseAnother() } }
                            .buttonStyle(.larp(.outline))
                    }
                    if folder.hasWriteError {
                        SettingsStatusLine(text: L10n.string("Impossibile scrivere nella cartella"), isFailure: true)
                    }
                }
            }
        }
    }
}
