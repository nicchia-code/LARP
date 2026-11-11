---
description: Use when building, testing, signing or releasing LARP, or when deciding where new code goes and which platform limits apply.
---
# Platform, build and release

## General
- macOS app for Apple silicon (arm64) only, macOS 26 or later; built for arm64 alone in Debug and Release, locally, in CI and in the release workflow. Every `xcodebuild` invocation passes `ARCHS=arm64`, because the Swift Package Manager dependencies do not inherit the project's architecture.
- Menu bar app without a Dock icon (agent app). Development language and all texts shown to the user are Italian.
- The Xcode project is generated with XcodeGen from `project.yml` and is not committed; sources under `Sources/LARP/` and tests under `Tests/LARPTests/` are picked up by folder, without editing `project.yml`.
- Not sandboxed (needed for the Core Audio process taps and free access to the app's folder in Application Support). Ad-hoc signed, hardened runtime off, not notarized.
- Swift 6 language mode with complete strict concurrency.
- Dependencies come only through Swift Package Manager. The WebRTC audio processing module is built from source as a local C++ package in `Packages/WebRTCAudioProcessing`, pinned to one WebRTC revision, used only for its echo canceller, exposed to Swift through a thin C wrapper; its vendored WebRTC files are not edited.
- omp is never bundled: it is an optional external program, needed only for transcript refinement and call summaries, found in the PATH of the user's login shell and started as a separate process. Only the transcript text is sent to it, never the audio.
- The app contacts no cloud service, account, telemetry or update service of its own.
- The behaviour of each Machine lives in a pure transition table separate from the code that runs the effects; every outside dependency (audio devices, speech, diarization, omp, permissions, panels, network, login item) sits behind a protocol so tests can replace it.
- Tests use Swift Testing and run inside the app. Tests that need Apple speech models, FluidAudio models, the microphone or the system audio carry the tag `requiresHardware`; the default test plan skips that tag, so CI never runs them.
- CI runs on every push and pull request on a `macos-26` runner: it installs XcodeGen, generates the project, builds and runs the tests.
- A release is published by pushing a tag `vX.Y.Z`: on a `macos-26` runner the workflow runs the same tests (a failure stops it before anything is published), builds Release for arm64, checks that the executable holds arm64 alone and carries the version and build number, creates `LARP-<version>.dmg` holding the app and a link to Applications, and publishes a GitHub Release named after the tag with an Italian installation text followed by the notes GitHub generates. The version is the tag without `v` and the build number is the workflow run number, both set at build time; `project.yml` is not edited. A pushed tag is never moved, deleted or recreated, even when its workflow failed: the fix goes out with the next patch version.
- Distribution is limited to the developer's Macs and a few trusted people with read access to the private repository; updates are manual.
