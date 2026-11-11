import Foundation

/// What the two global shortcuts do (machine `shortcuts`, whose combinations are kept by
/// `ShortcutsController`). Settings never depends on the call layer, so the app entry point
/// passes this to `ShortcutsController.start(perform:)`.
@MainActor
struct ShortcutActions {
    let recorder: Recorder
    let lifecycle: CallLifecycle
    let playback: PlaybackController

    func perform(_ shortcut: Shortcut) {
        switch shortcut {
        case .record:
            Task { await recorder.toggleRecording() }
        case .bookmark:
            BookmarkShortcut.perform(
                recordingElapsedSeconds: recorder.isRecording ? recorder.elapsedSeconds : nil,
                playback: playback, lifecycle: lifecycle)
        }
    }
}

/// `user.ADD_BOOKMARK` by shortcut.
@MainActor
enum BookmarkShortcut {
    /// During a recording (`recordingElapsedSeconds` is its elapsed time), adds a bookmark to the
    /// call being recorded at the time elapsed; otherwise, with the audio of a call loaded and
    /// playing or paused, adds it to that call at the time reached; otherwise does nothing.
    static func perform(recordingElapsedSeconds: Int?, playback: PlaybackController, lifecycle: CallLifecycle) {
        if let elapsed = recordingElapsedSeconds {
            lifecycle.addBookmarkToActiveRecording(atSeconds: TimeInterval(elapsed))
        } else if playback.state != .stopped, let callID = playback.callID, let call = lifecycle.call(id: callID) {
            lifecycle.addBookmark(to: call, at: playback.currentTime)
        }
    }
}
