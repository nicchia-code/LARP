---
status: approved
kind: import
requires:
- 5zk696pr
base:
  model/capture/feature.md: new
  model/capture/microphone.md: new
  model/capture/recorder.md: new
  model/capture/system-audio.md: new
  requirements/data/capture.md: new
  requirements/rules/capture.md: new
  requirements/tech/capture.md: new
created: 2026-11-11T12:33:57.080Z
label: Import
job: a8nt702p
---
# Import: Capture

Importa la Feature `capture` così com'è nel codice: il `recorder` (proposta di registrazione quando un'app di chiamata nota inizia a usare il microfono, avvio a mano, permessi, fine della registrazione, tempo trascorso nella barra dei menu), il `microphone` (cattura del microfono predefinito con rimozione dell'eco tramite WebRTC AEC3, riavvio ai cambi dei dispositivi, perdita e ritorno) e il `system-audio` (process tap di Core Audio su un aggregate device privato, obbligatorio per una registrazione legata a un'app di chiamata e facoltativo per una registrazione a mano, perdita e ritorno). Sono importati anche i frammenti `data`, `rules` e `tech` della cattura: formato e scrittura delle tracce, tabella delle app di chiamata, permessi, costanti audio e vincoli dei thread. Cartelle lette: `Sources/LARP/Capture/`, `Sources/LARP/Recording/`, `Packages/WebRTCAudioProcessing/` (solo il wrapper C), la parte di cattura di `Sources/LARP/Call/CallLifecycle+Recording.swift`, `Sources/LARP/App/MenuBarContent.swift`, `Sources/LARP/App/LARPApp.swift` e i test corrispondenti in `Tests/LARPTests/`.

## Doubts
- `Recorder.beginRecording` (Sources/LARP/Capture/Recorder.swift): se l'app di chiamata smette di usare il microfono mentre si controllano i permessi di una proposta accettata, parte comunque una registrazione non legata ad alcuna app, con l'audio di sistema facoltativo; sembra un caso non previsto.
- `Recorder.beginRecording`: se l'utente avvia a mano e nel frattempo compare una proposta, non viene registrato nulla (`guard startedFromProposal`) e la proposta resta; il "Registra" dell'utente va perso.
- `Recorder.beginRecording` e `CallLifecycle.recordingStarted` (Sources/LARP/Call/CallLifecycle+Recording.swift): il recorder mostra la registrazione in corso (punto rosso e tempo) prima che la cattura sia partita e torna a riposo da solo quando la cattura fallisce.
- `endRecorderRecording` (Sources/LARP/App/LARPApp.swift, Sources/LARP/Call/CallLifecycle+Recording.swift): ferma la registrazione in corso del recorder senza verificare che sia quella la cui cattura è fallita; con un ferma/avvia rapido può fermare una registrazione più recente.
- `TrackPipeline.process` e `fillSilence` (Sources/LARP/Recording/TrackPipeline.swift): un errore di scrittura su disco viene solo registrato nel log; la traccia smette di crescere per il resto della registrazione senza che l'utente lo sappia.
- `SystemAudioTap.TapError.isPermissionDenied` (Sources/LARP/Recording/SystemAudioTap.swift): qualunque errore nella creazione del tap è trattato come permesso mancante, anche quando la causa potrebbe essere un'altra.
- `TrackPipeline.process`: ogni traccia inizia al primo audio arrivato, e l'audio di sistema viene avviato prima del microfono; non è determinato se lo scarto iniziale tra le due tracce sia voluto o trascurabile.
- `SystemAudioTap.restart`: al ritorno dell'audio di sistema la notizia sulla rimozione dell'eco non passa dal filtro di `CallAudioCapture.start`, quindi l'avviso sulle cuffie può comparire anche con il microfono perso.
- `EchoRemover.restart` e `EchoRemover.finish` (Sources/LARP/Recording/EchoRemover.swift): i campioni del microfono in attesa di completare un frame da 10 ms vengono scartati a ogni riavvio del cancellatore d'eco e alla fine della registrazione.
- `CallAudioCapture(events:)` in Sources/LARP/App/LARPApp.swift: ogni evento della cattura arriva al recorder in un `Task` separato sul main actor; non è determinato se l'ordine tra eventi emessi da thread diversi (per esempio perdita dell'audio di sistema e notizia sull'eco) sia sempre rispettato.
