import Testing

extension Tag {
    /// Tests that need Apple speech models, FluidAudio models, the microphone or
    /// system audio. They cannot run on a CI runner and are skipped there: the
    /// test plan `Tests/LARP.xctestplan` excludes this tag.
    ///
    /// Usage: `@Test(.tags(.requiresHardware)) func ...`
    @Tag static var requiresHardware: Self
}
