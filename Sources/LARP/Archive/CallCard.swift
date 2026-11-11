import SwiftUI

/// A call in the grid of the library: a white card with, from the top, the day and time and the
/// call app, the title (two lines at most), the opening sentence of the summary or else the
/// status, and a row with the avatars of the speakers, the duration (not while recording), the chip
/// with the number of action items not done yet when there are some, and the status chip: lime when
/// the transcription is complete, `#ECECE4` while the call is being worked on.
struct CallCard: View {
    let call: Call
    let select: () -> Void
    @Environment(CallLifecycle.self) private var lifecycle

    var body: some View {
        let status = lifecycle.statusLabel(of: call)
        let openActions = SummaryContent(call: call)?.openActionCount ?? 0
        Button(action: select) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Eyebrow(verbatim: ArchiveFormat.cardDayAndTime(call.startedAt))
                    Spacer(minLength: 8)
                    Eyebrow(verbatim: call.appLabel())
                }
                Text(call.displayTitle)
                    .larpText(.cardTitle)
                    .foregroundStyle(LARPColor.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                // Left out while the waveform is not worked out.
                if let bars = call.waveform {
                    CallWaveformStrip(bars: bars, hasLines: !call.lines.isEmpty)
                }
                Text(verbatim: Self.summaryLine(of: call, status: status))
                    .font(LARPFont.inter(13))
                    .foregroundStyle(LARPColor.textSecondary)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                footer(status: status, openActions: openActions)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .larpCard(.light, padding: 22)
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.larpPlain)
        .accessibilityElement(children: .combine)
    }

    private func footer(status: String?, openActions: Int) -> some View {
        HStack(spacing: 10) {
            LARPAvatarStack(
                items: CallSpeakers.speakers(of: call).map {
                    .init(id: $0.id, initial: $0.initial, kind: $0.kind, participantNumber: $0.participantNumber)
                })
            if call.state != .recording {
                Text(verbatim: ArchiveFormat.cardDuration(call.duration))
                    .font(LARPFont.inter(12))
                    .foregroundStyle(LARPColor.textSecondary)
            }
            Spacer(minLength: 8)
            if openActions > 0 {
                LARPStatusChip(text: Self.actionsChipText(openActions), kind: .done)
            }
            if let status {
                LARPStatusChip(text: status, kind: .neutral)
            } else {
                LARPStatusChip(text: L10n.string("Trascritta"), kind: .done)
            }
        }
        .frame(minHeight: 24)
    }

    /// The opening sentence of the summary as shown, else the status of the call.
    static func summaryLine(of call: Call, status: String?, language: AppLanguage = .current) -> String {
        if let opening = SummaryContent(call: call, language: language)?.opening {
            return opening.plain
        }
        return status ?? ""
    }

    /// "1 azione" / "1 action", "<n> azioni" / "<n> actions".
    static func actionsChipText(_ count: Int, language: AppLanguage = .current) -> String {
        L10n.count(count, one: "1 azione", other: "%lld azioni", language: language)
    }
}
