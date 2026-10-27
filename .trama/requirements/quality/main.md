---
description: Use when the work touches privacy, reliability, performance or recovery after a crash.
---
# Quality

## General
- Privacy: audio and transcripts never leave the Mac; the only network use is the download of Apple speech models and FluidAudio models.
- On an M1 Mac, recording with live transcription of both tracks must not drop audio during a one-hour call.

## call/Recording
- Audio is flushed to disk at least every 5 seconds, so a crash or power loss loses at most the last 5 seconds.
- At launch, any call still in Recording is closed at its last saved audio before anything else happens.
