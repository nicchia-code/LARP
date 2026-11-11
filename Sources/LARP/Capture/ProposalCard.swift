import SwiftUI

/// The proposal to record a call, the same wherever it appears: the eyebrow with a red dot
/// "In onda ora · <call app>", the title of the meeting (or "Call rilevata") in Bricolage Grotesque
/// 22 px semibold white (at most two lines) with the number of people under it in 13 px `#A3A69B`
/// when known, a full-width lime button 52 px high, radius 12, with an ink dot, "Registra
/// questa call" and the shortcut on its right, and under it the text button "Non questa". It sits on
/// a dark surface.
struct ProposalCard: View {
    let appName: String
    let meeting: ProposalMeeting
    /// `user.ACCEPT_PROPOSAL`.
    let accept: @MainActor () -> Void
    /// `user.DISMISS_PROPOSAL`.
    let dismiss: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ProposalEyebrow(appName: appName)
            ProposalTitle(meeting: meeting, size: 22)
            ProposalAcceptButton(fullWidth: true, accept: accept)
                .padding(.top, 6)
            ProposalDismissButton(dismiss: dismiss)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .larpAppearance(dark: true)
    }
}

/// The proposal as the banner at the top of the library: an ink card, radius 18, with the eyebrow and
/// the title on the left, and on the right the text button "Non questa" and the lime button.
struct ProposalBanner: View {
    let appName: String
    let meeting: ProposalMeeting
    let accept: @MainActor () -> Void
    let dismiss: @MainActor () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                ProposalEyebrow(appName: appName)
                ProposalTitle(meeting: meeting, size: 24)
            }
            Spacer(minLength: 12)
            ProposalDismissButton(dismiss: dismiss)
            ProposalAcceptButton(fullWidth: false, accept: accept)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(LARPColor.ink, in: RoundedRectangle(cornerRadius: 18))
        .larpAppearance(dark: true)
    }
}

/// "● IN ONDA ORA · <APP>": a red `#FF5A40` dot and the eyebrow.
private struct ProposalEyebrow: View {
    let appName: String

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(LARPColor.recording).frame(width: 8, height: 8)
            Eyebrow(verbatim: L10n.format("In onda ora · %@", appName))
        }
    }
}

/// The text button "Non questa" in 13 px `#E9EAE3`.
private struct ProposalDismissButton: View {
    let dismiss: @MainActor () -> Void

    var body: some View {
        Button(action: dismiss) {
            Text("Non questa")
                .font(LARPFont.inter(13))
                .foregroundStyle(LARPColor.textOnDark)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        }
        .buttonStyle(.larpPlain)
    }
}

/// The title of the meeting, or "Call rilevata", and under it, when known, the number of people.
private struct ProposalTitle: View {
    let meeting: ProposalMeeting
    let size: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: meeting.displayTitle)
                .font(LARPFont.display(size, .semibold))
                .tracking(-0.01 * size)
                .foregroundStyle(.white)
                .lineLimit(2)
            if let people = meeting.peopleText {
                Text(verbatim: people)
                    .font(LARPFont.inter(13))
                    .foregroundStyle(LARPColor.textMuted)
            }
        }
    }
}

/// The lime button "Registra questa call", 52 px high, radius 12.
private struct ProposalAcceptButton: View {
    let fullWidth: Bool
    let accept: @MainActor () -> Void

    var body: some View {
        Button(action: accept) {
            HStack(spacing: 10) {
                Circle().fill(LARPColor.ink).frame(width: 10, height: 10)
                Text("Registra questa call")
                    .font(LARPFont.inter(14, .semibold))
                if fullWidth { Spacer(minLength: 0) }
                if let keys = ShortcutsController.shared.display(for: .record) {
                    ShortcutKeys(text: keys, style: .plain(LARPColor.ink))
                }
            }
            .foregroundStyle(LARPColor.ink)
            .padding(.horizontal, 20)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: 52)
            .background(LARPColor.lime, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.larpPlain)
        .larpFocusOutline(cornerRadius: 12)
    }
}
