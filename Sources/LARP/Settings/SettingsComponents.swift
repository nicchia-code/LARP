import SwiftUI

/// A section of the settings page: a white card with its heading in Bricolage Grotesque 20 px
/// semibold and its rows below, each under a `#E4E4DC` divider.
struct SettingsCard<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(LARPFont.display(20, .semibold))
                .tracking(-0.01 * 20)
                .foregroundStyle(LARPColor.ink)
            VStack(alignment: .leading, spacing: 0) {
                content
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .larpCard(padding: 24)
    }
}

/// A row of a settings card: the label in 13 px semibold, an optional explanation under it in 12 px
/// `#5A5D55`, the control on the right and, when given, a line under both.
struct SettingsRow<Control: View, Below: View>: View {
    let label: LocalizedStringKey
    let explanation: LocalizedStringKey?
    let control: Control
    let below: Below
    /// The colour of the explanation: `#5A5D55`, or `#B42A18` for a failure (`explanationTint`).
    private var explanationColor = LARPColor.textSecondary

    init(
        _ label: LocalizedStringKey,
        explanation: LocalizedStringKey? = nil,
        @ViewBuilder control: () -> Control,
        @ViewBuilder below: () -> Below
    ) {
        self.label = label
        self.explanation = explanation
        self.control = control()
        self.below = below()
    }

    /// The same row with the explanation in another colour.
    func explanationTint(_ color: Color) -> Self {
        var row = self
        row.explanationColor = color
        return row
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(LARPColor.border).frame(height: 1)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                            .font(LARPFont.inter(13, .semibold))
                            .foregroundStyle(LARPColor.ink)
                        if let explanation {
                            Text(explanation)
                                .font(LARPFont.inter(12))
                                .foregroundStyle(explanationColor)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    control
                }
                below
            }
            .padding(.vertical, 14)
        }
    }
}

extension SettingsRow where Below == EmptyView {
    init(
        _ label: LocalizedStringKey,
        explanation: LocalizedStringKey? = nil,
        @ViewBuilder control: () -> Control
    ) {
        self.init(label, explanation: explanation, control: control, below: { EmptyView() })
    }
}

/// A segmented choice with the single value "Sul Mac", shown as the selected ink segment: the
/// engine of the transcription is fixed, the cloud one is not developed.
struct SettingsSingleSegment: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(LARPFont.inter(12, .medium))
            .foregroundStyle(LARPColor.lime)
            .padding(.horizontal, 14)
            .frame(height: 28)
            .background(LARPColor.ink, in: RoundedRectangle(cornerRadius: 8))
            .padding(3)
            .background(LARPColor.chipNeutral, in: RoundedRectangle(cornerRadius: 11))
    }
}

/// A line of state under a row, in 12 px `#5A5D55`, or `#B42A18` for a failure.
struct SettingsStatusLine: View {
    let text: String
    var isFailure = false
    var isBusy = false

    var body: some View {
        HStack(spacing: 6) {
            if isBusy {
                ProgressView().controlSize(.small)
            }
            Text(verbatim: text)
                .font(LARPFont.inter(12))
                .foregroundStyle(isFailure ? LARPColor.destructive : LARPColor.textSecondary)
        }
    }
}

/// The state of omp, shown under an omp switch that is on.
struct OmpStatusLine: View {
    let state: AssistantStatusController.State

    var body: some View {
        if let text = SettingsText.assistantStatus(state) {
            SettingsStatusLine(
                text: text,
                isFailure: state == .assistantMissing,
                isBusy: state == .checking)
        }
    }
}
