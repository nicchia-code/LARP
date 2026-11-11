---
technical: false
refs:
  - system-audio
  - time.SYSTEM_AUDIO_STALLED
  - requirements/tech#system-audio
  - requirements/rules#system-audio
---

# Audio di sistema a frequenza reale

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
