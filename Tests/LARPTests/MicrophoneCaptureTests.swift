import Foundation
import Synchronization
import Testing

@testable import LARP

@Suite("Microphone capture", .serialized, .tags(.requiresHardware))
struct MicrophoneCaptureTests {
    @Test("the microphone starts with voice processing on and reports it once")
    func startsWithVoiceProcessing() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "larp-mic-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let pipeline = try TrackPipeline(track: .microphone, folder: folder, sink: nil)
        let reports = Mutex<[Bool]>([])
        let microphone = MicrophoneCapture(pipeline: pipeline) { available in
            reports.withLock { $0.append(available) }
        }

        try microphone.start()
        microphone.stop()
        await pipeline.finish()

        #expect(reports.withLock { $0 } == [true])
    }
}
