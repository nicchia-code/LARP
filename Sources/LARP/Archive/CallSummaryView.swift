import SwiftUI

/// The "Sintesi" tab of a call: what the summary is doing, above the summary when there is
/// one (an earlier summary stays while a new one is written or a try failed), and the summary
/// itself, read-only but selectable.
struct CallSummaryView: View {
    let call: Call

    var body: some View {
        let content = SummaryContent(call: call)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch call.summaryState {
                case .writing:
                    Label {
                        Text("Sintesi in corso…")
                    } icon: {
                        ProgressView().controlSize(.small)
                    }
                    .foregroundStyle(.secondary)
                case .awaitingRetry:
                    Label("Sintesi non riuscita, nuovo tentativo appena possibile", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                case .none, .written:
                    if content == nil {
                        ContentUnavailableView("Nessuna sintesi", systemImage: "text.badge.minus")
                            .frame(maxWidth: .infinity)
                    }
                }
                if let content {
                    ForEach(Array(content.sections.enumerated()), id: \.offset) { _, section in
                        SummarySectionView(section: section)
                    }
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
    }
}

private struct SummarySectionView: View {
    let section: SummaryContent.Section

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(section.title)
                .font(.headline)
            switch section.body {
            case .items(let items):
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•")
                        Text(item)
                    }
                }
            case .none(let label):
                Text(label).foregroundStyle(.secondary)
            case .text(let text):
                Text(text)
            }
        }
    }
}
