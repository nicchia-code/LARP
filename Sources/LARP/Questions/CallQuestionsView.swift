import SwiftUI

/// The questions asked about the call shown (`call-question`), at the bottom of the left column of
/// the page: each question in 13 px semibold with its answer in 15 px under it, the last one with
/// "omp sta rispondendo…" while it waits, a failed one with "Riprova" as a link; then the ink field
/// "Chiedi qualcosa a questa call", 52 px high, radius 26, with the lime button "Chiedi" inside it
/// on the right. The field is shown only while questions and translations with omp are on, and is
/// available only for a call with lines and while no question is being answered.
struct CallQuestionsView: View {
    let call: Call
    let questions: CallQuestions
    private let controller = CallQuestionsController.shared

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        let entries = questions.entries(of: call.id)
        VStack(alignment: .leading, spacing: 12) {
            if !entries.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(entries) { entry in
                            QuestionRow(entry: entry, names: participantNames, canRetry: questions.canAsk(call)) {
                                // `user.ASK_CALL`, from "Riprova".
                                questions.retry(entry.id, of: call)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                }
                .defaultScrollAnchor(.bottom)
                .frame(maxHeight: 260)
            }
            if controller.isOn { field }
        }
    }

    /// The names the user gave, by participant number: they replace "Partecipante <numero>" in an answer.
    private var participantNames: [Int: String] {
        Dictionary(
            call.participants.compactMap { participant in
                participant.name.flatMap { $0.isEmpty ? nil : (participant.number, $0) }
            },
            uniquingKeysWith: { first, _ in first })
    }

    private var field: some View {
        HStack(spacing: 10) {
            TextField(
                text: $draft,
                prompt: Text("Chiedi qualcosa a questa call").foregroundStyle(LARPColor.textMuted)
            ) { EmptyView() }
            .textFieldStyle(.plain)
            .font(LARPFont.inter(13))
            .foregroundStyle(LARPColor.white)
            .tint(LARPColor.lime)
            .focused($isFocused)
            .onSubmit(ask)
            .disabled(!questions.canAsk(call))
            Button("Chiedi", action: ask)
                .buttonStyle(LARPButtonStyle(kind: .primary, height: 36, radius: 18))
                .disabled(!questions.canAsk(call))
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .frame(height: 52)
        .background(LARPColor.ink, in: RoundedRectangle(cornerRadius: 26))
        .accessibilityElement(children: .contain)
    }

    /// `user.ASK_CALL`: the question typed goes to the list and the field is emptied.
    private func ask() {
        if questions.ask(draft, of: call) { draft = "" }
    }
}

/// A question of the list with what omp answered.
private struct QuestionRow: View {
    let entry: CallQuestions.Entry
    let names: [Int: String]
    /// "Riprova" is available: no other question is being answered.
    let canRetry: Bool
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: entry.question)
                .font(LARPFont.inter(13, .semibold))
                .foregroundStyle(LARPColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            switch entry.status {
            case .answering:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("omp sta rispondendo…")
                }
                .font(LARPFont.inter(13))
                .foregroundStyle(LARPColor.textSecondary)
            case .answered(let answer):
                Text(verbatim: SummaryContent.replacingParticipants(in: answer, names: names))
                    .font(LARPFont.inter(15))
                    .foregroundStyle(LARPColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            case .failed:
                HStack(spacing: 12) {
                    Text("omp non ha potuto rispondere")
                        .font(LARPFont.inter(13))
                        .foregroundStyle(LARPColor.destructive)
                    Button("Riprova", action: retry)
                        .buttonStyle(.larpLink)
                        .disabled(!canRetry)
                }
            case .stopped:
                Text("Domanda interrotta")
                    .font(LARPFont.inter(13))
                    .foregroundStyle(LARPColor.textSecondary)
            }
        }
    }
}

/// The link of the translation under the heading of the transcript panel (`transcript-translation`):
/// "Traduci" while the call can be translated, "Traduzione in corso…" while omp translates and
/// "Mostra originale" while the translation is shown, with the eyebrow "TRADOTTO IN <LINGUA>"; a
/// failed translation shows "Traduzione non riuscita" in `#B42A18` next to the link.
struct TranscriptTranslationBar: View {
    let call: Call
    let translation: TranscriptTranslation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if translation.isTranslated(call.id), let target = translation.target {
                Eyebrow(verbatim: Self.eyebrow(target))
            }
            HStack(spacing: 12) {
                link
                if translation.hasFailed(call.id) {
                    Text("Traduzione non riuscita")
                        .font(LARPFont.inter(13))
                        .foregroundStyle(LARPColor.destructive)
                }
            }
        }
    }

    @ViewBuilder
    private var link: some View {
        if translation.isTranslating(call.id) {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Traduzione in corso…")
            }
            .font(LARPFont.inter(13))
            .foregroundStyle(LARPColor.textSecondary)
        } else if translation.isTranslated(call.id) {
            // `user.SHOW_ORIGINAL`.
            Button("Mostra originale") { translation.showOriginal() }
                .buttonStyle(.larpLink)
        } else if translation.canTranslate(call) {
            // `user.TRANSLATE_TRANSCRIPT`.
            Button("Traduci") { translation.translate(call) }
                .buttonStyle(.larpLink)
        }
    }

    /// "Tradotto in italiano" / "Tradotto in inglese", in the language of the interface.
    static func eyebrow(_ target: TranscriptTranslationRequest.Target, language: AppLanguage = .current) -> String {
        switch target {
        case .italian: L10n.string("Tradotto in italiano", language: language)
        case .english: L10n.string("Tradotto in inglese", language: language)
        }
    }
}
