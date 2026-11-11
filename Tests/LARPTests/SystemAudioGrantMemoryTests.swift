import Testing

@testable import LARP

@Suite("System audio permission without asking")
struct SystemAudioGrantMemoryTests {
    @Test("nothing is granted without asking until a tap has been created")
    func startsNotGranted() {
        let permissions = SystemRecordingPermissions(memory: SystemAudioGrantMemory(), createTap: { true })
        #expect(!permissions.systemAudioGrantedWithoutAsking())
    }

    @Test("reading without asking never creates a tap")
    func readingDoesNotProbe() {
        let permissions = SystemRecordingPermissions(
            memory: SystemAudioGrantMemory(), createTap: { Issue.record("a tap was created"); return true })
        #expect(!permissions.systemAudioGrantedWithoutAsking())
        #expect(!permissions.bothGrantedWithoutAsking())
    }

    @Test("a tap that was created is remembered")
    func successIsRemembered() {
        let permissions = SystemRecordingPermissions(memory: SystemAudioGrantMemory(), createTap: { true })
        #expect(permissions.systemAudioGranted())
        #expect(permissions.systemAudioGrantedWithoutAsking())
    }

    @Test("a tap that could not be created is not remembered")
    func failureIsNotRemembered() {
        let permissions = SystemRecordingPermissions(memory: SystemAudioGrantMemory(), createTap: { false })
        #expect(!permissions.systemAudioGranted())
        #expect(!permissions.systemAudioGrantedWithoutAsking())
    }

    @Test("the memory is shared by every reader of it and lasts for the launch")
    func sharedMemory() {
        let memory = SystemAudioGrantMemory()
        let probe = SystemRecordingPermissions(memory: memory, createTap: { true })
        let recorder = SystemRecordingPermissions(memory: memory, createTap: { false })
        #expect(!recorder.systemAudioGrantedWithoutAsking())
        _ = probe.systemAudioGranted()
        #expect(recorder.systemAudioGrantedWithoutAsking())
        // A later failed probe does not forget it.
        #expect(!recorder.systemAudioGranted())
        #expect(recorder.systemAudioGrantedWithoutAsking())
    }
}
