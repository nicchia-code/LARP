import AVFoundation
import Foundation
import Synchronization
import Testing

@testable import LARP

@Suite("Microphone capture", .serialized, .tags(.requiresHardware))
struct MicrophoneCaptureTests {
    private func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: "larp-mic-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    @Test("the microphone starts without voice processing and reports the echo canceller once")
    func startsWithTheEchoCancellerAndNoVoiceProcessing() async throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let pipeline = try TrackPipeline(track: .microphone, folder: folder, sink: nil)
        let echoRemover = EchoRemover(output: pipeline)
        let reports = Mutex<[CaptureEvent]>([])
        let microphone = MicrophoneCapture(pipeline: pipeline, echoRemover: echoRemover) { event in
            reports.withLock { $0.append(event) }
        }

        try microphone.start()
        let voiceProcessing = microphone.isVoiceProcessingEnabled
        microphone.stop()
        await echoRemover.finish()
        await pipeline.finish()

        #expect(!voiceProcessing)
        #expect(reports.withLock { $0 } == [.echoCancellation(available: true)])
    }

    @Test("without an echo remover the microphone reports that nothing is removed from it")
    func startsWithoutEchoRemover() async throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let pipeline = try TrackPipeline(track: .microphone, folder: folder, sink: nil)
        let reports = Mutex<[CaptureEvent]>([])
        let microphone = MicrophoneCapture(pipeline: pipeline) { event in
            reports.withLock { $0.append(event) }
        }

        try microphone.start()
        microphone.stop()
        await pipeline.finish()

        #expect(reports.withLock { $0 } == [.echoCancellation(available: false)])
    }
}
