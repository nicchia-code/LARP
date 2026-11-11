---
description: Use when changing how call apps are detected, how the microphone and the system audio are captured, the echo canceller or the threads of the capture.
---
# Capture on Core Audio and AVFoundation

## recorder
- The recorder runs on the main actor and is observable by the menu bar; it hands its start and stop events to a single consumer through an unbounded stream, buffered until iteration starts.
- Call apps using the microphone are detected from the Core Audio process objects: a listener on the process list and one on the running-input property of each process, on a private serial queue; never by polling. The parent processes are read through the BSD process information, and their bundle identifiers through the running applications of AppKit.
- The microphone permission goes through `AVAudioApplication`. The system audio permission is probed by creating and immediately destroying a private global process tap that excludes the app's own process.
- Proposals, warnings and notices are borderless non-activating panels at the status bar level, on every Space and beside full-screen apps, placed under the menu bar icon; alerts are modal and activate the app first.
- Detection, permissions, the proposal, the alerts and every notice sit behind protocols, replaced in tests.
- The global shortcuts are registered with `RegisterEventHotKey` of the Carbon framework, which needs no Accessibility permission; they are registered again whenever they change and unregistered when removed; the registration sits behind a protocol, replaced in tests.

## recording-view
- The pill is a borderless non-activating panel at the floating level, on every Space and beside full-screen apps, placed on the screen of the menu bar; the live window is a normal window that comes to the front when opened, without making the app appear in the Dock.
- Levels are measured on the private queue of each track, from the 16 kHz audio before it is written, and handed to the main actor at most 20 times a second; nothing is measured on the audio threads.
- The text being recognised comes from the volatile results of the live speech transcriber, which are passed to the live window and replaced by each new result; only final results become lines of the call.

## capture
- One capture per recording owns the two track writers, the echo remover, the microphone and the system audio. It starts the system audio first and the microphone second, and stops the microphone, then the system audio, then waits for the echo remover and the two tracks to finish.
- What the capture tells the recorder may be reported from any thread and is handed to the main actor.
- Audio threads only copy the buffer they get and return. Conversion to the storage format, echo cancellation, disk writes and the handing over to the live transcription run on private serial queues, one per track and one for the echo remover; every buffer keeps the format it was captured with and the system uptime of its last frame.
- Sample rate conversion uses one `AVAudioConverter` per stream, kept between buffers and rebuilt when the input format changes.
- The AAC files are written with `ExtAudioFile`, and the packet table is written out with `AudioFileOptimize`, because `AVAudioFile` keeps it in memory until the file is closed and an unclosed file could not be read at all.
- The microphone and the system audio sources are made by factories that tests replace.

## microphone
- Built on `AVAudioEngine`. A new engine is made at every start and restart, on the microphone to use: the chosen input device is set on the input node's audio unit as its current device, otherwise the default input device is used; its input node is tapped with buffers of 4096 frames in the format it reports at that moment, and a sample rate of zero or no channels means there is no microphone.
- macOS voice processing is never enabled: it would lower the audio of every other app and could change the level of the microphone.
- Changes are followed through the engine's configuration change notification, ignored when they come from an engine already replaced, and through Core Audio listeners on the default input device and on the device list, so that the chosen device is picked up again when it is connected; listeners run on a private queue and are removed outside the lock of the microphone. A new choice of microphone during a recording restarts the capture as a change of devices does.
- The echo canceller is WebRTC's AEC3 alone, from the local package built from source, reached through its thin C wrapper (create, destroy, process one reference frame, process one microphone frame); mobile mode is off. It is not thread-safe and is used only from the queue of the echo remover.
- The engine sits behind a protocol, replaced in tests by fake devices.

## system-audio
- Built on a Core Audio process tap: a mono global tap of every process except the app itself, not muted, private; read through a private, non-stacked aggregate device whose main and only sub-device is the current default output, with the tap started automatically and drift compensation on, and an I/O proc on its own queue.
- The format of the tap is read once per run and labels every buffer of that run; buffers arriving after a run has ended or stopped following the output are dropped.
- A run listens to the default output, the sample rate and liveness of the output, the sample rate and active sub-devices of the aggregate device and the format of the tap, on a private queue never on the I/O thread, and asks for a restart only when a signature of those values differs from the one taken at its start. A first check runs right after the start, for what changed while it was being set up.
- Starting and stopping run on one private serial queue, one thing at a time; while the system audio is lost, listeners on the default output and on the device list stand in for the run.
- A failure to create the tap is what macOS does when the system audio recording permission is missing.
- The Core Audio access sits behind a protocol, replaced in tests by fake devices.
