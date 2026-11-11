---
created: 2026-11-11T19:04:25.238Z
updated: 2026-11-11T19:04:25.238Z
summary: L'audio di sistema è letto alla frequenza reale dello stream del tap, riparte se si ferma per 2 secondi, e ogni traccia dura quanto la registrazione, con log diagnostico della cattura.
tasks:
- lr77qufy
- ut479hxd
cleared:
  lr77qufy:
    title: Audio di sistema a frequenza reale
    refs:
    - system-audio
    - time.SYSTEM_AUDIO_STALLED
    - requirements/tech#system-audio
    - requirements/rules#system-audio
    technical: false
    proposal: dlyxofoi
    label: Audio di sistema
    finished: 2026-11-11T18:51:26.356Z
    body: |-
      L'audio di sistema deve essere sempre registrato alla velocità a cui è stato sentito, anche quando le cuffie passano alla modalità chiamata (a una frequenza più bassa) perché il loro microfono viene aperto.

      **Frequenza reale.** Il formato che etichetta l'audio di sistema è quello reale dello stream del tap all'interno del dispositivo aggregato, letto dopo che il dispositivo aggregato è partito, alla frequenza a cui questo gira davvero; mai il formato che il tap dichiarava prima che l'aggregato fosse costruito. L'audio non viene mai letto a una frequenza diversa da quella a cui arriva. Subito dopo l'avvio viene fatto un primo controllo, per ciò che è cambiato durante la preparazione (ad esempio le cuffie che passano in modalità chiamata quando si apre il microfono). Quando il formato dello stream del tap cambia, o è diverso da quello usato per etichettare l'audio, la cattura riparte da zero sull'uscita predefinita attuale; una raffica di cambiamenti la fa ripartire una volta sola, e un vuoto più lungo di un secondo viene riempito di silenzio nella traccia.

      **Solo lo stream del tap.** Viene letto solo lo stream del tap, trovato per la sua posizione fra gli stream d'ingresso del dispositivo aggregato, mai dando per scontato che sia il primo e mai lo stream del microfono di una cuffia usata come uscita. Se lo stream del tap non si trova, la cattura non parte come quando il tap non può essere creato: se la registrazione è legata a un'app di chiamata, la registrazione non può partire; se è stata avviata a mano, prosegue con il solo microfono, la traccia di sistema resta vuota e nulla viene tolto dal microfono. Se succede durante una ripartenza, l'audio di sistema è perso.

      **Audio fermo.** L'audio di sistema è considerato fermo quando per 2 secondi non arriva alcun audio mentre è catturato; il silenzio di quando non suona niente conta comunque come audio arrivato. L'attesa riparte a ogni avvio e a ogni ripartenza della cattura. Quando è fermo, la cattura riparte da zero sull'uscita predefinita attuale senza dire nulla all'utente, e il vuoto viene riempito di silenzio nella traccia. Se non riesce a ripartire, l'audio di sistema diventa perso, con le stesse conseguenze di una ripartenza fallita dopo un cambio di dispositivi: il microfono non viene più ripulito dal suono degli altri, un avviso sull'eco ancora visibile scompare, un avviso duraturo sotto l'icona della barra dei menu dice che l'audio di sistema non è disponibile e che la registrazione prosegue senza gli altri partecipanti, e da quel momento ogni cambio dell'uscita predefinita o dei dispositivi audio collegati è un'occasione per ripartire. Viene segnalato l'evento di audio di sistema perso.

      **Allo stop.** Quando la registrazione si ferma, la traccia di sistema viene riempita di silenzio fino alla fine della registrazione, anche se il suo audio aveva smesso di arrivare, e poi chiusa.

      **Prove.** Le prove con dispositivi finti devono coprire: un tap con frequenza diversa da quella dell'aggregato fin dall'avvio, un cambio di frequenza dopo l'avvio, un elenco d'ingresso con più stream, e un audio di sistema fermo.

      ## Code notes

      Commit: 58d947126f08b8c7e4128d08782a627080bde977

      - `Sources/LARP/Recording/CoreAudioSystemDriver.swift`: `CoreAudioSystemCapture.start` (~105-130) reads `readTapFormat()` (`kAudioTapPropertyFormat`) before the aggregate settles and builds `Signature` from it — read the tap stream's format from the aggregate's input streams after start instead; add it to `Signature`/`signature(of:)` and compare with the run's label format in `propertiesChanged`. `startIO` uses only `mBuffers[0]`: select the tap stream's buffer by index. Failed `AVAudioPCMBuffer` init / `stale` are dropped silently.
      - Stall watch: on the run's private queue, never the I/O thread; reset at every start/restart; on fire ask a restart like a device change; failure → `lost` path in `Sources/LARP/Recording/SystemAudioTap.swift` (`restart`, `changePending` folds bursts, `lost`, `observeDevices`). Echo suspend/resume already handled.
      - Gap filler: `TrackPipeline.process`, `gapTolerance = 1`, only reacts when the next buffer arrives. Track start/end fill belongs to another Task.
      - Another Task logs tap-reported vs real stream format at each start/restart: expose both formats from the driver.
      - Tests: `Tests/LARPTests/SystemAudioTapTests.swift` (`followsTheSampleRate`), `Tests/LARPTests/FakeAudioDevices.swift` — `FakeSystemDriver` only models rate changes after start; `FakeTone.next(rate:labelRate:)` can simulate a wrong label. Extend fakes for tap rate ≠ aggregate rate at start, multi-buffer input list, stall.
      - Conventions: audio threads only copy (`AVAudioPCMBuffer.copy()`), one private serial queue per stream, `AudioFormats.storage` = 16 kHz mono float.
  ut479hxd:
    title: Tracce lunghe come la registrazione
    refs:
    - requirements/data#capture
    - requirements/rules#capture
    - requirements/tech#capture
    technical: true
    proposal: dlyxofoi
    label: Audio di sistema
    finished: 2026-11-11T19:01:12.660Z
    body: |-
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
---
# Cattura audio affidabile e tracce complete

L'audio di sistema viene etichettato con il formato reale dello stream del tap nel dispositivo aggregato, letto dopo l'avvio, trovato per posizione fra gli stream d'ingresso; un cambio di formato o 2 secondi senza audio fanno ripartire la cattura da zero, e se non riesce l'audio di sistema è perso. Ogni traccia comincia all'inizio della registrazione e allo stop è riempita di silenzio fino al momento dello stop; il log della cattura riporta formati, secondi scritti e aggiunti e buffer scartati.
