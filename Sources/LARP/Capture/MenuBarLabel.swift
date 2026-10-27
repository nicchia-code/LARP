import AppKit
import SwiftUI

/// The menu bar icon: a microphone outline when idle, a filled red dot with the
/// elapsed time while recording.
struct MenuBarLabel: View {
    let recorder: Recorder

    var body: some View {
        if recorder.isRecording {
            HStack(spacing: 4) {
                Image(nsImage: Self.recordingDot)
                Text(Recorder.formatElapsed(recorder.elapsedSeconds))
                    .monospacedDigit()
            }
        } else {
            Image(systemName: "mic")
        }
    }

    /// A non-template image, so that the menu bar keeps it red.
    private static let recordingDot: NSImage = {
        let image = NSImage(size: NSSize(width: 10, height: 10), flipped: false) { rect in
            NSColor.systemRed.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        image.isTemplate = false
        return image
    }()
}
