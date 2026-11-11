import AppKit
import SwiftUI

/// The welcome window: an ink panel on the left, the step on paper on the right.
/// "Passo 1 di 2 · Permessi" and "Passo 2 di 2 · Scelte" are the two steps of the
/// `onboarding` machine; the choices of the second step are those of the settings.
struct OnboardingView: View {
    static let windowSize = CGSize(width: 960, height: 680)
    /// The ink panel takes about 45 % of the window.
    static let panelWidth: CGFloat = 432

    let onboarding: OnboardingController

    var body: some View {
        HStack(spacing: 0) {
            OnboardingPanel()
                .frame(width: Self.panelWidth)
            Group {
                switch onboarding.state {
                case .choicesStep:
                    OnboardingChoicesStep(onboarding: onboarding)
                default:
                    OnboardingPermissionsStep(onboarding: onboarding)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .larpSurface(.paper)
        }
        .frame(width: Self.windowSize.width, height: Self.windowSize.height)
        .larpEnvironment()
        .ignoresSafeArea()
    }
}

// MARK: - Ink panel

private struct OnboardingPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                LarpMark(size: 30)
                Text("LARP")
                    .larpText(LARPTextStyle.wordmark)
                    .foregroundStyle(LARPColor.white)
            }
            // Room for the buttons of the window above the mark.
            .padding(.top, 72)

            Spacer(minLength: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("Ogni call,")
                    .foregroundStyle(LARPColor.white)
                Text("messa agli atti.")
                    .foregroundStyle(LARPColor.ink)
                    .padding(.horizontal, 10)
                    .background(LARPColor.lime, in: RoundedRectangle(cornerRadius: 10))
                    .padding(.leading, -10)
            }
            .font(LARPFont.display(52, .bold))
            .tracking(-0.03 * 52)
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            Text("LARP ascolta dal tuo Mac, scrive chi ha detto cosa e ti consegna la versione breve. Nessun bot entra nella riunione.")
                .font(LARPFont.inter(15))
                .lineSpacing(3)
                .foregroundStyle(LARPColor.textOnDark)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 20)

            WaveformBars(bars: Self.bars, barWidth: 3.5, gap: 2.37, floor: 4)
                .frame(height: 72)
                .padding(.top, 40)
                .padding(.bottom, 48)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .larpSurface(.ink)
    }

    /// 60 bars in lime, lilac, peach and white; the same every time the window opens.
    static let bars: [WaveformBars.Bar] = {
        let colors = [LARPColor.lime, LARPColor.lilac, LARPColor.peach, LARPColor.white]
        return (0..<60).map { index in
            let wave = sin(Double(index) * 0.55) * 0.5 + sin(Double(index) * 1.7 + 1) * 0.3
            let level = min(max(0.55 + wave * 0.5, 0.12), 1)
            return WaveformBars.Bar(level: level, color: colors[(index / 3 + index / 11) % colors.count])
        }
    }()
}

// MARK: - Steps

/// What both steps share: the eyebrow, the rows, and at the bottom the line about the
/// settings with the button that goes on.
private struct OnboardingStep<Content: View>: View {
    let eyebrow: LocalizedStringKey
    let buttonTitle: LocalizedStringKey
    let action: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(eyebrow)
                .larpText(LARPTextStyle.eyebrow)
                .textCase(.uppercase)
                .foregroundStyle(LARPColor.textSecondary)
                .padding(.top, 62)

            content

            Spacer(minLength: 16)

            Text("Tutto si può cambiare più tardi nelle Impostazioni.")
                .font(LARPFont.inter(12))
                .foregroundStyle(LARPColor.textSecondary)

            Button(action: action) {
                Text(buttonTitle)
            }
            .buttonStyle(.larp(.dark))
            .fixedSize()
            .padding(.top, 16)
            .padding(.bottom, 48)
        }
        .padding(.horizontal, 56)
    }
}

private struct OnboardingPermissionsStep: View {
    let onboarding: OnboardingController
    private let teams = TeamsAccessController.shared
    private let calendar = CalendarAccessController.shared

    var body: some View {
        OnboardingStep(
            eyebrow: "Passo 1 di 2 · Permessi", buttonTitle: "Continua →",
            action: { onboarding.continueSetup() }
        ) {
            VStack(spacing: 0) {
                OnboardingRule()
                OnboardingPermissionRow(
                    number: "01", name: "Microfono", explanation: "La tua voce nella conversazione",
                    isGranted: onboarding.microphoneGranted
                ) {
                    Task { await onboarding.allowMicrophone() }
                }
                OnboardingRule()
                OnboardingPermissionRow(
                    number: "02", name: "Audio di sistema",
                    explanation: "Tutti gli altri, da Teams, Zoom, Meet e ogni altra app",
                    isGranted: onboarding.systemAudioGranted
                ) {
                    Task { await onboarding.allowSystemAudio() }
                }
                OnboardingRule()
                // `user.ALLOW_TEAMS_ACCESS`: passed to the access to Teams.
                OnboardingPermissionRow(
                    number: "03", name: "Microsoft Teams",
                    explanation: "Titolo della riunione e chi parla, letti con l'Accessibilità",
                    isGranted: teams.isAllowed, isOptional: true
                ) {
                    teams.allowTeamsAccess()
                }
                OnboardingRule()
                // `user.CONNECT_CALENDAR`: passed to the access to the calendar.
                OnboardingPermissionRow(
                    number: "04", name: "Calendario",
                    explanation: "Dà il nome alle registrazioni e indica chi c'era",
                    isGranted: calendar.isConnected, isOptional: true,
                    actionTitle: "Collega", isOutline: true, grantedTitle: "Collegato"
                ) {
                    Task { await calendar.connect() }
                }
                OnboardingRule()
            }
            .padding(.top, 28)
        }
        // Coming back from System Settings shows the permission just granted.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            onboarding.refreshMicrophone()
        }
    }
}

/// A 1 px line in ink between the rows.
private struct OnboardingRule: View {
    var body: some View {
        Rectangle().fill(LARPColor.ink).frame(height: 1)
    }
}

private struct OnboardingPermissionRow: View {
    let number: String
    let name: LocalizedStringKey
    let explanation: LocalizedStringKey
    let isGranted: Bool
    /// Teams and the calendar can be left out: "· facoltativo" after the name.
    var isOptional = false
    /// The button that grants it: "Consenti", or "Collega" for the calendar (outline).
    var actionTitle: LocalizedStringKey = "Consenti"
    var isOutline = false
    /// The lime chip once it is granted: "Consentito", or "Collegato" for the calendar.
    var grantedTitle: LocalizedStringKey = "Consentito"
    let allow: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(number)
                .font(LARPFont.display(28, .bold))
                .foregroundStyle(LARPColor.ink)
                .frame(width: 52, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                if isOptional {
                    // "Microsoft Teams · facoltativo": the name in ink, the qualifier in `#5A5D55`.
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(name).foregroundStyle(LARPColor.ink)
                        Text("· facoltativo").foregroundStyle(LARPColor.textSecondary)
                    }
                    .font(LARPFont.inter(15, .semibold))
                } else {
                    Text(name)
                        .font(LARPFont.inter(15, .semibold))
                        .foregroundStyle(LARPColor.ink)
                }
                Text(explanation)
                    .font(LARPFont.inter(13))
                    .foregroundStyle(LARPColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if isGranted {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                    Text(grantedTitle)
                }
                .font(LARPFont.inter(13, .semibold))
                .foregroundStyle(LARPColor.ink)
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(LARPColor.lime, in: Capsule())
                .accessibilityElement(children: .combine)
            } else if isOutline {
                Button(actionTitle, action: allow)
                    .buttonStyle(.larp(.outline))
            } else {
                Button(actionTitle, action: allow)
                    .buttonStyle(.larp(.dark))
            }
        }
        .padding(.vertical, 22)
    }
}

private struct OnboardingChoicesStep: View {
    let onboarding: OnboardingController
    private let language = TranscriptionLanguageController.shared
    private let refinement = TranscriptRefinementController.shared
    private let summaries = CallSummariesController.shared
    private let assistantStatus = AssistantStatusController.shared

    var body: some View {
        OnboardingStep(
            eyebrow: "Passo 2 di 2 · Scelte", buttonTitle: "Inizia →",
            action: { onboarding.finishSetup() }
        ) {
            VStack(alignment: .leading, spacing: 0) {
                Text("In che lingua parli nelle call?")
                    .font(LARPFont.inter(15, .semibold))
                    .foregroundStyle(LARPColor.ink)
                    .padding(.top, 28)

                HStack(spacing: 12) {
                    ForEach(TranscriptionLanguage.allCases) { option in
                        OnboardingLanguageCard(name: option.displayName, isSelected: language.language == option) {
                            language.choose(option)
                        }
                    }
                }
                .padding(.top, 14)

                Text(SettingsText.languageStatus(language.status))
                    .font(LARPFont.inter(13))
                    .foregroundStyle(LARPColor.textSecondary)
                    .padding(.top, 10)

                OnboardingRule().padding(.top, 24)
                OnboardingSwitchRow(
                    title: "Rifinisci il testo con omp", explanation: "Corregge le parole riconosciute male",
                    isOn: Binding(
                        get: { refinement.isOn },
                        set: { $0 ? refinement.turnOn() : refinement.turnOff() }
                    ),
                    status: refinement.isOn ? SettingsText.assistantStatus(assistantStatus.state) : nil,
                    statusIsMissing: assistantStatus.state == .assistantMissing)
                OnboardingRule()
                OnboardingSwitchRow(
                    title: "Sintetizza quando la call finisce", explanation: "Sintesi, decisioni e azioni scritte da omp",
                    isOn: Binding(
                        get: { summaries.isOn },
                        set: { $0 ? summaries.turnOn() : summaries.turnOff() }
                    ),
                    status: summaries.isOn ? SettingsText.assistantStatus(assistantStatus.state) : nil,
                    statusIsMissing: assistantStatus.state == .assistantMissing)
                OnboardingRule()

                Text("Sul Mac: l'audio non lascia il computer")
                    .font(LARPFont.inter(13, .medium))
                    .foregroundStyle(LARPColor.ink)
                    .padding(.top, 18)
            }
        }
    }
}

/// A large choice card: the chosen one ink with a lime radio dot and white text, the other
/// white with a border.
private struct OnboardingLanguageCard: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().strokeBorder(isSelected ? LARPColor.lime : LARPColor.chipBorder, lineWidth: 1.5)
                    if isSelected { Circle().fill(LARPColor.lime).padding(4) }
                }
                .frame(width: 18, height: 18)
                Text(name)
                    .font(LARPFont.inter(15, .semibold))
                    .foregroundStyle(isSelected ? LARPColor.white : LARPColor.ink)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(isSelected ? LARPColor.ink : LARPColor.white, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                if !isSelected {
                    RoundedRectangle(cornerRadius: 14).strokeBorder(LARPColor.border, lineWidth: 1)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.larpPlain)
        .larpFocusOutline(cornerRadius: 14)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct OnboardingSwitchRow: View {
    let title: LocalizedStringKey
    let explanation: LocalizedStringKey
    @Binding var isOn: Bool
    /// The state of omp, while the switch is on.
    let status: String?
    let statusIsMissing: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(LARPFont.inter(15, .semibold))
                    .foregroundStyle(LARPColor.ink)
                Text(explanation)
                    .font(LARPFont.inter(13))
                    .foregroundStyle(LARPColor.textSecondary)
                if let status {
                    Text(status)
                        .font(LARPFont.inter(12))
                        .foregroundStyle(statusIsMissing ? LARPColor.destructive : LARPColor.textSecondary)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 8)
            LARPSwitch(isOn: $isOn)
                .padding(.top, 2)
        }
        .padding(.vertical, 18)
    }
}
