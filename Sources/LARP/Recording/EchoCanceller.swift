import WebRTCAudioProcessing

/// WebRTC's echo canceller (AEC3) alone: it removes from the microphone the sound that
/// the reference signal (what the Mac plays) left in it. 16 kHz mono float audio in
/// 10 ms frames; no gain control, no noise suppression, no other stage, so the level
/// of the voice is not changed.
///
/// Not thread-safe: use from one queue. The echo path it learned is lost with the
/// instance: make a new one to start from scratch.
final class EchoCanceller {
    /// Samples in one frame: 10 ms at 16 kHz.
    static let frameSamples = Int(WAP_FRAME_SAMPLES)

    private let handle: OpaquePointer

    /// `nil` when the echo canceller cannot be created.
    init?() {
        guard let handle = wap_echo_canceller_create() else { return nil }
        self.handle = handle
    }

    deinit {
        wap_echo_canceller_destroy(handle)
    }

    /// Gives the canceller one frame of what the Mac plays. Returns whether it was taken.
    @discardableResult
    func processReference(_ frame: UnsafePointer<Float>) -> Bool {
        wap_echo_canceller_process_reference(handle, frame) == 0
    }

    /// Removes the echo from one frame of the microphone, writing the result to `output`
    /// (which may be the memory of `input`). Returns whether it was done; when it was not,
    /// `output` is left as it was.
    @discardableResult
    func processMicrophone(_ input: UnsafePointer<Float>, into output: UnsafeMutablePointer<Float>) -> Bool {
        wap_echo_canceller_process_microphone(handle, input, output) == 0
    }
}
