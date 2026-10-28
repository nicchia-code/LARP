---
description: Use when the work touches privacy, reliability, performance, recovery after a crash or the stability of automated tests.
---
# Quality

## General
- Privacy: audio never leaves the Mac. Transcripts never leave the Mac, except the lines of a call sent to omp for refinement, only while transcript refinement is on; what is sent is limited to what `requirements/rules#call` lists.
- The app's own network use is only the download of Apple speech models and FluidAudio models; omp reaches the model provider configured in omp.
- On an M1 Mac, recording with live transcription of both tracks must not drop audio during a one-hour call.
- Automated tests are deterministic: a test waits for the effect it checks (for example the call it expects on a fake), never for an intermediate state that comes before that effect and never for a fixed time, so that it passes on every run, on a slow CI runner as on the developer's Mac.

## call/Recording
- Audio is flushed to disk at least every 5 seconds, so a crash or power loss loses at most the last 5 seconds.
- At launch, any call still in Recording is closed at its last saved audio before anything else happens.

## call
- Deleting a call while its transcription, separation of participants or refinement runs in the background never crashes the app: the work in progress stops and, once the call is deleted, never reads or writes that call, its lines or its participants again.
- An automated test deletes a call during each of these background works and passes on every run, on the CI runner as on the developer's Mac.

## recorder/Recording
- Without headphones, with a call app playing the other participants through the Mac's built-in speakers at normal volume, the other participants are not audible in the microphone track and produce no "Me" lines; this is verified on a real Mac, since automated tests cannot play through speakers.
- On a real Mac, with no call going on and no other app using the microphone, "Registra" from Idle records the user's voice in the microphone track and it is transcribed as "Me"; this is verified on a real Mac, since automated tests use fake audio devices.
- Recording does not change any volume: on a real Mac, during a call on built-in speakers and on headphones, the call app sounds as loud with a recording running as without it, other apps (for example music) are not lowered, and the input volume of the microphone in System Settings and the level the other participants hear stay the same before, during and after the recording.
- An automated test checks the echo canceller with synthetic audio, without speakers: a reference signal and a microphone signal made of that reference delayed and attenuated plus a separate "user" signal. After the first 2 seconds, in the parts where only the reference plays, the echo left in the cleaned microphone is at least 20 dB below the echo in the input; in the parts where only the user speaks, the user's level is kept within 3 dB.
