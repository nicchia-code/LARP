import SwiftUI

/// The sections of the settings page, in the order of the sidebar and of the page. The selected
/// one in the sidebar is the last one clicked; a click brings its card into view.
enum SettingsSection: Hashable, CaseIterable, Identifiable {
    case recording
    case transcription
    case summaries
    case privacy
    case integrations
    case shortcuts

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .recording: "Registrazione"
        case .transcription: "Trascrizione"
        case .summaries: "Sintesi"
        case .privacy: "Privacy e archivio"
        case .integrations: "Esportazione e integrazioni"
        case .shortcuts: "Scorciatoie"
        }
    }
}

/// The settings page (`main-window/Settings shown`): it takes the whole window. On the left the
/// sidebar with "‹ Archivio" (`user.CLOSE_SETTINGS`) and the names of the sections; on the right
/// the eyebrow, the title and the sections as white cards in two columns, one when the page is
/// narrower than 900 px. Values live in `UserDefaults` under the keys of `SettingsKey`.
struct SettingsPage: View {
    /// `user.CLOSE_SETTINGS`: back to the library.
    let close: () -> Void

    private let language: TranscriptionLanguageController
    private let refinement: TranscriptRefinementController
    private let summaries: CallSummariesController
    private let summaryLanguage: SummaryLanguageController
    private let assistantStatus: AssistantStatusController
    private let launchAtLogin: LaunchAtLogin
    private let questions: CallQuestionsController

    @State private var selected: SettingsSection = .recording
    @State private var pageWidth: CGFloat = 1000

    /// Below this width of the page the cards sit in one column.
    private static let twoColumnsWidth: CGFloat = 900

    init(
        close: @escaping () -> Void,
        language: TranscriptionLanguageController = .shared,
        refinement: TranscriptRefinementController = .shared,
        summaries: CallSummariesController = .shared,
        summaryLanguage: SummaryLanguageController = .shared,
        assistantStatus: AssistantStatusController = .shared,
        launchAtLogin: LaunchAtLogin = .shared,
        questions: CallQuestionsController = .shared
    ) {
        self.close = close
        self.language = language
        self.refinement = refinement
        self.summaries = summaries
        self.summaryLanguage = summaryLanguage
        self.assistantStatus = assistantStatus
        self.launchAtLogin = launchAtLogin
        self.questions = questions
    }

    var body: some View {
        ScrollViewReader { proxy in
            HStack(spacing: 0) {
                sidebar(proxy)
                page
            }
        }
        // `user.OPEN_SETTINGS`: the page is made every time the settings are opened.
        .onAppear {
            SettingsEvents.openSettings(launchAtLogin: launchAtLogin, assistantStatus: assistantStatus)
        }
    }

    // MARK: Sidebar

    private func sidebar(_ proxy: ScrollViewProxy) -> some View {
        LARPSidebar {
            VStack(alignment: .leading, spacing: 24) {
                Button(action: close) {
                    Text("‹ Archivio")
                        .font(LARPFont.inter(13))
                        .foregroundStyle(LARPColor.textMuted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.larpPlain)
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(SettingsSection.allCases) { section in
                        SettingsSidebarItem(title: section.title, isSelected: section == selected) {
                            selected = section
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(section, anchor: .top)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Page

    private var page: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow("Impostazioni")
                    Text("Fallo tuo.")
                        .larpText(.pageTitle)
                        .foregroundStyle(LARPColor.ink)
                }
                cards
            }
            .padding(.horizontal, 36)
            .padding(.top, 28)
            .padding(.bottom, 36)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .larpSurface(.paper)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { pageWidth = $0 }
    }

    /// Two columns, the sections alternating left and right in their order; one column when the
    /// page is narrower than 900 px.
    @ViewBuilder
    private var cards: some View {
        let sections = SettingsSection.allCases
        if pageWidth < Self.twoColumnsWidth {
            VStack(spacing: 16) {
                ForEach(sections) { card(for: $0) }
            }
        } else {
            let left = sections.indices.filter { $0.isMultiple(of: 2) }.map { sections[$0] }
            let right = sections.indices.filter { !$0.isMultiple(of: 2) }.map { sections[$0] }
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 16) {
                    ForEach(left) { card(for: $0) }
                }
                VStack(spacing: 16) {
                    ForEach(right) { card(for: $0) }
                }
            }
        }
    }

    @ViewBuilder
    private func card(for section: SettingsSection) -> some View {
        Group {
            switch section {
            case .recording: recordingCard
            case .transcription: transcriptionCard
            case .summaries: summariesCard
            case .privacy: PrivacySettingsCard()
            case .integrations: IntegrationsSettingsCard()
            case .shortcuts: shortcutsCard
            }
        }
        .id(section)
    }

    // MARK: Cards

    /// The **Registrazione** section: call detection, the call apps watched, automatic recording and
    /// the microphone.
    private var recordingCard: some View {
        RecordingSettingsCard()
    }

    private var transcriptionCard: some View {
        SettingsCard(title: "Trascrizione") {
            SettingsRow("Motore", explanation: "L'audio non lascia il computer") {
                SettingsSingleSegment(title: "Sul Mac")
            }
            SettingsRow("Lingua", explanation: "Vale per le registrazioni che iniziano dopo la scelta.") {
                LARPChoiceBox(value: language.language.displayName, minWidth: 140) {
                    ForEach(TranscriptionLanguage.allCases) { option in
                        Button(option.displayName) { language.choose(option) }
                    }
                }
            } below: {
                SettingsStatusLine(
                    text: SettingsText.languageStatus(language.status),
                    isBusy: language.status == .checking || language.status == .downloading)
            }
            SpeakerIdentificationRow()
            SettingsRow("Rifinisci il testo con omp") {
                LARPSwitch(
                    isOn: Binding(
                        get: { refinement.isOn },
                        set: { $0 ? refinement.turnOn() : refinement.turnOff() }
                    )
                )
                .accessibilityLabel("Rifinisci il testo con omp")
            } below: {
                if refinement.isOn { OmpStatusLine(state: assistantStatus.state) }
            }
        }
    }

    private var summariesCard: some View {
        SettingsCard(title: "Sintesi") {
            SettingsRow(
                "Sintetizza quando la call finisce",
                explanation: "Sintesi, decisioni e azioni scritte da omp"
            ) {
                LARPSwitch(
                    isOn: Binding(
                        get: { summaries.isOn },
                        set: { $0 ? summaries.turnOn() : summaries.turnOff() }
                    )
                )
                .accessibilityLabel("Sintetizza quando la call finisce")
            } below: {
                if summaries.isOn { OmpStatusLine(state: assistantStatus.state) }
            }
            SettingsRow("Lingua della sintesi") {
                LARPChoiceBox(value: L10n.string(summaryLanguage.choice.title), minWidth: 140) {
                    ForEach(SummaryLanguageChoice.allCases) { option in
                        Button(L10n.string(option.title)) { summaryLanguage.choose(option) }
                    }
                }
            }
            SettingsRow(
                "Domande e traduzioni con omp",
                explanation: "Chiedi qualcosa a una call e traducine la trascrizione"
            ) {
                LARPSwitch(
                    isOn: Binding(
                        get: { questions.isOn },
                        set: { $0 ? questions.turnOn() : questions.turnOff() }
                    )
                )
                .accessibilityLabel("Domande e traduzioni con omp")
            } below: {
                if questions.isOn { OmpStatusLine(state: assistantStatus.state) }
            }
        }
    }

    private var shortcutsCard: some View {
        SettingsCard(title: "Scorciatoie") {
            ShortcutRow(.record, title: "Avvia o ferma la registrazione")
            ShortcutRow(.bookmark, title: "Aggiungi segnalibro")
            SettingsRow("Apri LARP all'accesso", explanation: "Resta discreto nella barra dei menu") {
                LARPSwitch(
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }
                    )
                )
                .accessibilityLabel("Apri LARP all'accesso")
            } below: {
                VStack(alignment: .leading, spacing: 4) {
                    if launchAtLogin.requiresApproval {
                        SettingsStatusLine(
                            text: L10n.string("Approva LARP in Impostazioni di Sistema › Generali › Elementi login."))
                    }
                    if let message = launchAtLogin.errorMessage {
                        SettingsStatusLine(text: message, isFailure: true)
                    }
                }
            }
        }
    }
}

/// An item of the sidebar of the settings: 13 px `#E9EAE3`, 8 × 10 px padding, radius 8; the
/// selected one is `#23251F` with lime semibold text, as in the library.
private struct SettingsSidebarItem: View {
    let title: LocalizedStringKey
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(LARPFont.inter(13, isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? LARPColor.lime : LARPColor.textOnDark)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(isSelected ? LARPColor.darkSelected : .clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.larpPlain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
