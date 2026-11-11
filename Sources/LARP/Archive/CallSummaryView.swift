import SwiftUI

/// The summary tab of the page of a call: what the summary is doing, and the summary itself, read-only
/// but selectable: an earlier summary stays while a new one is written or a try failed. The opening
/// sentence comes first, then the sections; the action items can be ticked
/// (`user.TOGGLE_ACTION_ITEM`) and the time of a decision plays the audio from its line
/// (`user.SELECT_DECISION`). "Sintetizza" / "Rigenera" sit on the right of the tabs of the page.
struct CallSummaryView: View {
    let call: Call
    let playback: PlaybackController
    @Environment(CallLifecycle.self) private var lifecycle

    var body: some View {
        let content = SummaryContent(call: call)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                status(hasSummary: content != nil)
                if let content {
                    if let opening = content.opening {
                        OpeningSentence(opening: opening)
                    }
                    ForEach(Array(content.sections.enumerated()), id: \.offset) { _, section in
                        SummarySectionView(
                            section: section,
                            // `user.SELECT_DECISION`: only for the call whose audio is loaded.
                            playDecision: { start in
                                guard playback.callID == call.id else { return }
                                playback.selectDecision(lineStart: start)
                            },
                            // `user.TOGGLE_ACTION_ITEM`.
                            toggleAction: { lifecycle.toggleActionItem(of: call, at: $0.index) })
                    }
                }
            }
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func status(hasSummary: Bool) -> some View {
        switch call.summaryState {
        case .writing:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Sintesi in corso…")
            }
            .font(LARPFont.inter(15))
            .foregroundStyle(LARPColor.textSecondary)
        case .awaitingRetry:
            Text("Sintesi non riuscita, nuovo tentativo appena possibile")
                .font(LARPFont.inter(15))
                .foregroundStyle(LARPColor.textSecondary)
        case .none, .written:
            if !hasSummary {
                Text("Nessuna sintesi")
                    .font(LARPFont.inter(15))
                    .foregroundStyle(LARPColor.textSecondary)
            }
        }
    }
}

/// The opening sentence in Inter 24 px medium, line height 1.3, −0.01 em, with its key part on a lime
/// background. The background of a run of text has neither radius nor padding in SwiftUI: thin spaces
/// around the key part stand for the 4 px of padding.
private struct OpeningSentence: View {
    let opening: SummaryContent.Opening

    var body: some View {
        Text(attributed)
            .font(LARPFont.inter(24, .medium))
            .tracking(-0.01 * 24)
            // Line height 1.3: 31.2 px against the natural 29 px of Inter at 24 px.
            .lineSpacing(2.2)
            .foregroundStyle(LARPColor.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var attributed: AttributedString {
        var result = AttributedString(opening.before)
        if !opening.key.isEmpty {
            var key = AttributedString("\u{2009}\(opening.key)\u{2009}")
            key.backgroundColor = LARPColor.lime
            result += key
        }
        result += AttributedString(opening.after)
        return result
    }
}

/// A section of the summary: the eyebrow with its title and, below, its items. The decisions are
/// numbered "01", "02" in Bricolage Grotesque 20 px, separated by dividers, each with the time of its
/// line in a chip; the action items are rows with a tick.
private struct SummarySectionView: View {
    let section: SummaryContent.Section
    let playDecision: (TimeInterval) -> Void
    let toggleAction: (SummaryContent.Action) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(verbatim: section.title)
            switch section.body {
            case .items(let items):
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        Text(item)
                            .font(LARPFont.inter(15))
                            .foregroundStyle(LARPColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            case .decisions(let decisions):
                self.decisions(decisions)
            case .actions(let actions):
                VStack(spacing: 8) {
                    ForEach(actions, id: \.index) { action in
                        SummaryActionRow(action: action, toggle: { toggleAction(action) })
                    }
                }
            case .none(let label):
                Text(label)
                    .font(LARPFont.inter(15))
                    .foregroundStyle(LARPColor.textSecondary)
            case .text(let text):
                Text(text)
                    .font(LARPFont.inter(15))
                    .foregroundStyle(LARPColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func decisions(_ items: [SummaryContent.Decision]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index == 0 { Rectangle().fill(LARPColor.border).frame(height: 1) }
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    Text(verbatim: String(format: "%02d", index + 1))
                        .font(LARPFont.display(20, .semibold))
                        .foregroundStyle(LARPColor.ink)
                        .frame(width: 34, alignment: .leading)
                    Text(item.text)
                        .font(LARPFont.inter(15))
                        .foregroundStyle(LARPColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if let start = item.lineStart {
                        Button { playDecision(start) } label: { ClockChip(seconds: start) }
                            .buttonStyle(.larpPlain)
                    }
                }
                .padding(.vertical, 14)
                Rectangle().fill(LARPColor.border).frame(height: 1)
            }
        }
    }
}
