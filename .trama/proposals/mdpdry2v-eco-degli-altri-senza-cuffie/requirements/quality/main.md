---
description: Use when the work touches privacy, reliability, performance or recovery after a crash.
---
# Quality

## General
- Privacy: audio never leaves the Mac. Transcripts never leave the Mac, except the lines of a call sent to omp for refinement, only while transcript refinement is on; what is sent is limited to what `requirements/rules#call` lists.
- The app's own network use is only the download of Apple speech models and FluidAudio models; omp reaches the model provider configured in omp.
- On an M1 Mac, recording with live transcription of both tracks must not drop audio during a one-hour call.

## call/Recording
- Audio is flushed to disk at least every 5 seconds, so a crash or power loss loses at most the last 5 seconds.
- At launch, any call still in Recording is closed at its last saved audio before anything else happens.

## recorder/Recording
- Without headphones, with a call app playing the other participants through the Mac's built-in speakers at normal volume, the other participants are not audible in the microphone track and produce no "Me" lines; this is verified on a real Mac, since automated tests cannot play through speakers.
