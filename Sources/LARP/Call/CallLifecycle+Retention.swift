import Foundation
import os

extension CallLifecycle {
    private static var retentionLogger: Logger { Logger(subsystem: "com.larp.LARP", category: "retention") }

    /// A day of the retention is 24 hours.
    private static let retentionDay: TimeInterval = 24 * 60 * 60

    /// `time.AUDIO_RETENTION_CHECK_DUE`, `macos.APP_LAUNCHED` and `user.CHOOSE_AUDIO_RETENTION`: looks at
    /// the Ready calls and deletes the audio of those that were kept for too long. A check asked while
    /// another one runs waits for it, so a new choice is never lost. Returns when the check is done.
    func checkAudioRetention() async {
        let previous = audioRetentionCheck
        let check = Task {
            await previous?.value
            await runAudioRetentionCheck()
        }
        audioRetentionCheck = check
        await check.value
    }

    private func runAudioRetentionCheck() async {
        guard let days = audioRetentionDays() else { return }
        let cutoff = now().addingTimeInterval(-Double(days) * Self.retentionDay)
        for id in calls(in: [.ready]).map(\.id) {
            guard var call = call(id: id), isDueForRetention(call, cutoff: cutoff) else { continue }
            // The waveform stays when the audio goes: a call that has none yet gets it first.
            if call.waveform == nil {
                startWaveform(of: call)
                await runningWaveforms[id]?.task.value
                guard let again = self.call(id: id), isDueForRetention(again, cutoff: cutoff) else { continue }
                call = again
            }
            let urls = [AudioTrack.microphone, .system].map { $0.fileURL(of: call) }
            do {
                try await audioRemover.removeFiles(at: urls)
            } catch {
                // Skipped: it is looked at again at the next check.
                Self.retentionLogger.error("Removing audio failed: \(error.localizedDescription, privacy: .public)")
                continue
            }
            // The call may be gone while its files were being removed.
            guard let removed = self.call(id: id) else { continue }
            removed.audioRemovedAfterDays = days
            save()
        }
    }

    /// Whether the audio of `call` is to be deleted now: the machine `call` in **Ready** says so.
    private func isDueForRetention(_ call: Call, cutoff: Date) -> Bool {
        let hasFiles = [AudioTrack.microphone, .system].contains {
            FileManager.default.fileExists(atPath: $0.fileURL(of: call).path)
        }
        let event = CallEvent.audioRetentionCheck(
            limited: true,
            expired: call.startedAt < cutoff,
            hasAudio: call.audioRemovedAfterDays == nil && hasFiles,
            summaryBeingWritten: call.summaryState == .writing)
        return CallStateMachine.target(from: call.state, on: event) != nil
    }
}
