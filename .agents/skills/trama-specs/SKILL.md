---
name: trama-specs
description: Use when choosing, adding or using the project's languages, frameworks, libraries, data stores, tests, CI, repository, deployment, cloud resources or infrastructure as code.
---
# Project specs

The technologies this project is built, tested and released with, from the developer's Specs. An entry marked as chosen by the agent was picked by the agent itself, not named by the developer.

## Languages

- Swift 6

## Frameworks and libraries

- SwiftUI
- Speech (SpeechAnalyzer) macOS 26: on-device transcription with SpeechTranscriber, Italian and English
- Core Audio process taps (chosen by the agent: captures the system audio of every call app with only the system audio recording permission, without screen recording)
- AVFoundation (chosen by the agent: standard API for microphone capture, audio files and playback)
- FluidAudio: on-device speaker diarization on Core ML
- ServiceManagement (chosen by the agent: SMAppService is the system API for launch at login)
- XcodeGen (chosen by the agent: keeps the Xcode project as a readable, versioned project.yml)

## Data and persistence

- SwiftData: archive of calls, transcript lines and participants, in Application Support

## Testing

- Swift Testing

## CI

- GitHub Actions: on a macos-26 runner; build and test on every push and pull request; on every vX.Y.Z tag, test, build the Release configuration, package a DMG and publish a GitHub Release (chosen by the agent: macos-26 is the GitHub runner image with Xcode for macOS 26)

## Repository

- GitHub: private repository; the trusted people who install the app are read-only collaborators

## Deployment

- Local Xcode build: development builds, built and run on the developer's own Mac
- GitHub Releases: one Release per vX.Y.Z tag with an ad-hoc signed DMG made with hdiutil, for the developer's Macs and a few trusted people; no notarization, no public distribution, manual updates

## Notes

Target: Apple silicon Macs (M1 and later) with macOS 26 or later.
No cloud and no infrastructure files: everything runs on the Mac.

