import Foundation

extension CallLifecycle {
    /// Whether the text of a line of the call can be corrected: only when the call is ready.
    func canEditLines(of call: Call) -> Bool {
        CallStateMachine.target(from: call.state, on: .editLine(lineBelongsToCall: true, textIsEmpty: false)) != nil
    }

    /// `user.EDIT_LINE`: the line takes `text`, cleaned of the whitespace around it, and, when it keeps
    /// an original text from a refinement, so does its original text, so that a later refinement starts
    /// from it and restoring brings it back. Its speaker and original speaker do not change, and a
    /// correction alone never makes the call count as refined. Nothing happens for a line of another
    /// call, a text that is empty once cleaned, or a call that is not ready: the line stays as it was.
    func editLine(_ line: TranscriptLine, of call: Call, to text: String) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let event = CallEvent.editLine(lineBelongsToCall: line.call?.id == call.id, textIsEmpty: cleaned.isEmpty)
        guard CallStateMachine.target(from: call.state, on: event) != nil else { return }
        line.text = cleaned
        if line.originalText != nil {
            line.originalText = cleaned
        }
        apply(event, to: call)
    }
}
