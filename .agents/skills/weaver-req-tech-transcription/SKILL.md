---
name: weaver-req-tech-transcription
description: "Use when changing how calls are transcribed, separated, refined or summarised: speech recognition, diarization, omp process and protocol, concurrency of the call work."
---

# Technology and constraints

## transcription

- The call lifecycle is one shared object on the main actor that applies the transition tables of `call` and `call-summary`, saves the new state and then starts the work of the state entered. It owns the data container, so work still ending after everything else lets go of it does not break.
- The work of each state runs in tasks of its own, at most one per call for separation, refinement and summary; starting it again replaces the one running. Its result is applied only if the call still exists and is still in the state that started it; a stopped task is never reported as a failure.
- Speech recognition, voice separation and omp sit behind protocols, so tests replace them; the omp request is one protocol shared by refinement and summary, each of which gets its own instance and process.
- omp is spoken to with the Agent Client Protocol: JSON-RPC 2.0, one message per line on the process's standard input and output, implemented directly on `Foundation.Process` and pipes, without an ACP library. The standard error of omp is discarded, and writing to a process that has ended fails instead of ending the app.
- A request is `initialize` (protocol version 1, no file system and no terminal capability, client info LARP), then `session/new` in the temporary folder with no MCP servers, then one `session/prompt` with one text block. The client never chooses a model: omp uses its own default.
- The request runs off the main actor; cancelling the task that asked ends the omp process at once.

## call

- Speech recognition is Apple's on-device `SpeechAnalyzer` with one `SpeechTranscriber` per track, in the call's locale, reporting volatile results and audio time ranges; the same configuration serves live and file transcription.
- File transcription reads each track as an audio file and runs both tracks concurrently, off the main actor; cancelling it stops the analyzer at once.
- Live transcription converts the captured audio to the analyzer's best available format and feeds it through a stream per track, never on the capture queue; a conversion or analysis failure makes the session report that the recording was not fully transcribed live.

## call/Separating participants

- Voice separation is FluidAudio's offline diarizer on Core ML, run on the system audio file; the number of voices is detected automatically. Its models are downloaded on first use into the app's `Models/` folder and reused.
- The assignment of lines to voices is a pure function of the line spans and the voice segments, apart from the diarizer.
