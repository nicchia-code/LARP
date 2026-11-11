---
technical: true
refs:
  - requirements/data#capture
  - requirements/rules#capture
  - requirements/tech#capture
---
# Tracce lunghe come la registrazione

Ogni traccia scritta di una registrazione (microfono e audio di sistema) deve coprire tutta la registrazione, dal suo inizio allo stop, così che un tempo in una qualsiasi traccia sia il tempo trascorso dall'inizio della registrazione e ogni traccia scritta duri quanto la registrazione. Oggi, nell'ultima registrazione dello sviluppatore, la chiamata è durata 23,7 s ma la traccia dell'audio di sistema solo 12,3 s.

Quando il lavoro è finito deve valere:

- Ogni traccia comincia nel momento in cui la registrazione è cominciata, quando il suo file è stato creato, non al primo audio arrivato: l'audio che manca prima del primo pezzo arrivato viene riempito di silenzio come qualsiasi altro buco.
- L'audio mancante per più di 1 secondo in una traccia viene riempito di silenzio, in pezzi di al massimo 10 secondi; tra i buchi rientrano anche una cattura persa o bloccata (audio che smette di arrivare) e l'audio arrivato dopo l'inizio o finito prima della fine.
- Allo stop ogni traccia scritta viene riempita di silenzio fino al momento dello stop, sia che la sua sorgente sia persa, sia che abbia smesso di consegnare audio, sia che stia ancora funzionando; poi viene chiusa.
- Una traccia dell'audio di sistema che non è mai partita (registrazione avviata a mano che prosegue con il solo microfono) resta vuota, come oggi.
- In pausa entrambe le tracce continuano a ricevere silenzio della stessa lunghezza dell'audio che sostituisce; ogni pezzo d'audio è scritto nel file prima di essere passato alla trascrizione dal vivo; una traccia che non riesce a essere scritta smette di prendere audio per il resto della registrazione, come oggi.
- Log diagnostico, solo sul Mac, senza mai audio né testo del transcript, con la categoria della cattura: a ogni avvio e riavvio dell'audio di sistema il formato riportato dal tap e quello dello stream letto davvero; a ogni avvio e riavvio del microfono il formato catturato; allo stop, per ogni traccia, i secondi di audio scritti, i secondi di silenzio aggiunti e la durata della registrazione; per ogni sorgente, quanti buffer sono stati scartati e perché (run già finita o che non segue più l'uscita, buffer illeggibile, conversione fallita).

Decisioni dello sviluppatore: le tracce coprono la registrazione dall'inizio allo stop; il log diagnostico registra formati e durate; per le registrazioni già fatte non si fa nulla. La lettura dell'audio di sistema alla frequenza reale, la scelta dello stream del tap e il riavvio dopo 2 secondi senza audio sono in un'altra Task della stessa Proposal: questa Task registra nel log i due formati che quella cattura espone.

I test automatici devono coprire: una traccia il cui primo audio arriva qualche secondo dopo l'inizio, una sorgente che smette di consegnare senza essere persa e la registrazione che si ferma, una traccia scritta che dura quanto la registrazione in entrambi i casi, e la traccia di sistema mai partita che resta vuota.

## Code notes

Commit: 58d947126f08b8c7e4128d08782a627080bde977

- `Sources/LARP/Recording/TrackPipeline.swift`: `process` (~109-139) sets `startUptime` from the first buffer's `arrival` (else `createdUptime`), compares `arrival - startUptime` with `writer.framesWritten`, fills via `fillSilence`/`writeSilence` when the gap exceeds `gapTolerance = 1`, `silenceChunk` 10 s; `failed` stops the track after a write error (`catch` ~133-136). Make the start the creation/recording-start uptime and keep `finish(silenceUntil:)` filling.
- `Sources/LARP/Recording/CallAudioCapture.swift` `stop` (~135-144): `finish(silenceUntil:)` gets a time only when the source `isLost`; pass the stop uptime for every written track, and skip the system track when it never started.
- `arrival` is `systemUptime` read on the callback queue (mic: `MicrophoneEngine.swift` ~57-66; system: `CoreAudioSystemDriver.startIO`), not `AVAudioTime.hostTime`.
- Logging: existing failures log with subsystem `com.larp.LARP`, category `capture`; reuse that `Logger`. Drops today happen silently in `startIO` (`bufferListNoCopy` init nil, `stale`) and `EchoRemover` (`~141`, failed mic conversion); add counters there, report at stop. `AACFileWriter.framesWritten` gives seconds written.
- `AudioFileDuration.seconds(of:)` reads the length back (frames ÷ rate).
- Tests: `Tests/LARPTests/TrackPipelineTests.swift` already drives explicit arrival uptimes (`silenceUntilTheEnd`, `longLoss`, `gapFilledWhenAudioReturns`); `CallAudioCaptureTests.swift` with `FakeAudioDevices.swift`.
- Pitfall: `recoverInterruptedRecordings` overwrites the call duration with the file length after a crash; unaffected but don't break it.
