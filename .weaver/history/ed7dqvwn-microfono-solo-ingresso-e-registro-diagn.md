---
created: 2026-11-12T15:52:07.495Z
updated: 2026-11-12T15:52:07.495Z
summary: Il microfono si cattura con un'unità Core Audio solo in ingresso, che non si ferma ai cambi di uscita, e un registro diagnostico per area traccia cattura, rilevamento e Teams.
tasks:
- a7sg1ro6
- hi0pgny3
cleared:
  a7sg1ro6:
    title: Microfono solo ingresso
    refs:
    - microphone
    - requirements/rules#microphone
    - requirements/tech#microphone
    - specs#frameworks
    technical: false
    proposal: i0s24q50
    label: Teams e diagnostica
    finished: 2026-11-12T15:48:54.924Z
    body: |-
      La cattura del microfono durante una registrazione avviene direttamente dal dispositivo di ingresso con Core Audio, solo in ingresso: un'unità audio `kAudioUnitSubType_HALOutput` con ingresso abilitato e uscita disabilitata, con dispositivo corrente impostato sul microfono da usare (il dispositivo di ingresso scelto, se collegato e riconosciuto dal suo identificativo unico, altrimenti quello predefinito; con "Predefinito di sistema" sempre quello predefinito), avviata a ogni avvio e riavvio. `AVAudioEngine` non si usa più per il microfono, perché il suo lato di uscita lo ferma a ogni cambio dell'uscita (per esempio quando gli AirPods passano in modalità chiamata appena si apre il microfono). L'elaborazione vocale di macOS non viene mai attivata.

      A ogni avvio il formato si legge dal lato di ingresso del dispositivo; frequenza zero o nessun canale significa che non c'è microfono. La richiamata di ingresso rende in un buffer preparato in anticipo, lo copia e ritorna: niente lock, allocazioni o log sul thread audio. Ogni buffer mantiene il formato di cattura e il tempo di sistema del suo ultimo frame.

      I cambiamenti si seguono con listener Core Audio su una coda privata, rimossi fuori dal lock del microfono:
      - dispositivo di ingresso predefinito ed elenco dei dispositivi (così il dispositivo scelto viene ripreso quando lo si ricollega);
      - frequenza, formato di stream e vitalità del dispositivo in uso: riavviano la cattura;
      - uscita predefinita e sua frequenza: creano solo un nuovo cancellatore d'eco, senza riaprire il microfono e senza buchi nella traccia.

      Il microfono si riapre solo se cambia il microfono da usare, se cambia il suo formato o se sparisce; una nuova scelta dell'utente durante la registrazione riavvia la cattura come un cambio di dispositivi (solo se il microfono da usare cambia). Un buco dovuto a un riavvio vero è riempito di silenzio nella traccia.

      Un nuovo cancellatore d'eco (AEC3 di WebRTC, da solo, modalità mobile spenta, impara il percorso d'eco da zero) si crea a ogni avvio e riavvio del microfono, a ogni cambio dell'uscita predefinita o del suo formato mentre il microfono prosegue, e a ogni ritorno dell'audio di sistema; si scarta mentre l'audio di sistema è perso. Senza cancellatore il microfono va alla traccia così com'è. Quando cambia solo l'uscita: se il cancellatore si può creare, l'avviso sull'eco ancora visibile scompare; se non si può, l'utente viene avvisato per 10 secondi di usare le cuffie. Se il riavvio non riesce il microfono è perso: avviso persistente sotto l'icona della barra dei menu che il microfono non è disponibile e la registrazione prosegue senza la voce dell'utente; ogni successivo cambio di dispositivi o di microfono scelto è un'occasione per ripartire, e al ritorno l'avviso scompare. Tutti gli altri comportamenti (avvio dopo l'audio di sistema, fallimento all'avvio, perdita e ritorno dell'audio di sistema, fine registrazione) restano quelli del Model.

      La nuova cattura deve continuare a scrivere nel registro diagnostico (Task "Registro diagnostico", area `capture`) il formato catturato a ogni avvio e riavvio, il motivo di ogni riavvio (microfono da usare cambiato, formato del microfono cambiato, microfono sparito, microfono scelto dall'utente), ogni nuovo cancellatore creato perché è cambiata solo l'uscita, e ogni perdita e ritorno del microfono; mai dal thread audio, solo dalle code private. Le righe di `os.Logger` restano.

      L'unità di ingresso e i suoi listener stanno dietro un protocollo, sostituito nei test da dispositivi finti.

      ## Code notes
      Commit: 09822d2c2cd4d67434f3e6f8e5dbb2030694288a

      - `Sources/LARP/Recording/MicrophoneCapture.swift` (~136-217): `installTapAndStart`, `start(_:)`, `restart(_:)`, `Trigger` (`.configurationChange`, `.devicesChanged`, `.choice`). Oggi `.configurationChange` (da `AVAudioEngineConfigurationChange`) riavvia sempre: va sostituito da trigger distinti (formato/vitalità del dispositivo → riavvio; uscita → solo `echoRemover.reset()`). `restart` gira sotto `lock`: log ed eventi dopo il lock, come fa `events`.
      - `Sources/LARP/Recording/MicrophoneEngine.swift` (~58-73): `AVMicrophoneEngine.start` e l'observer; il motore è dietro un protocollo: sostituire l'implementazione con l'unità HAL, adeguando i finti.
      - `Sources/LARP/Recording/EchoRemover.swift` (~60-90): `reset`, `suspendReference`, `resumeReference`; AEC3 solo sulla coda dell'echo remover.
      - `Sources/LARP/Recording/CoreAudioSystemDriver.swift`: schemi riusabili per i listener (`Signature`, `propertiesChanged`, coda privata); commento ~177 sulle cuffie Bluetooth in modalità chiamata.
      - `Sources/LARP/Recording/CaptureLog.swift`: `CaptureLog.microphoneStarted`; aggiungere qui i motivi di riavvio.
      - Test: `Tests/LARPTests/CallAudioCaptureTests.swift`, `FakeAudioDevices.swift`, `TrackPipelineTests.swift`; aggiungere un caso "cambia solo l'uscita → nessun riavvio, reset del cancellatore".
  hi0pgny3:
    title: Registro diagnostico
    refs:
    - requirements/data#General
    - requirements/quality#General
    - requirements/tech#General
    - requirements/tech#capture
    technical: true
    proposal: i0s24q50
    label: Teams e diagnostica
    finished: 2026-11-12T15:48:54.961Z
    body: |-
      LARP tiene un registro diagnostico proprio, sempre attivo e senza interruttore, per capire a posteriori cosa è successo durante una chiamata. Il registro di macOS resta com'è: il file si aggiunge, non lo sostituisce.

      Quando il Task è finito:

      - Il registro sta in `~/Library/Logs/LARP/`, creata se manca, con un file di testo UTF-8 per giorno, `LARP-<yyyy-MM-dd>.log`. Ogni riga è un evento: data e ora locali in ISO 8601 con millisecondi, area (`detection`, `teams`, `capture`) e messaggio, separati da spazi. Ogni riga arriva su disco prima che sia scritta la successiva, così un crash o un Mac bloccato non perde le righe già scritte. Le righe sono scritte da una coda seriale privata; un errore di scrittura è ignorato e non tocca mai una registrazione.
      - I file più vecchi di 30 giorni sono eliminati all'avvio e una volta al giorno mentre l'app è aperta.
      - Il registro non contiene mai audio, testo delle trascrizioni, nomi di persone, titoli o altri testi letti da Teams o dal calendario: solo identificativi di processi e app, durate, conteggi, formati e motivi.
      - Area `capture`: le righe che la cattura scrive oggi nel registro di macOS (formati a ogni avvio e riavvio di audio di sistema e microfono, secondi scritti, silenzio aggiunto e lunghezza della registrazione per traccia alla fine, buffer scartati e perché) sono scritte anche nel file, insieme al motivo di ogni riavvio del microfono (microfono da usare cambiato, formato cambiato, microfono sparito, microfono scelto dall'utente) e a ogni nuovo eliminatore dell'eco creato perché è cambiata solo l'uscita; al motivo di ogni riavvio dell'audio di sistema (quale valore della sua firma è cambiato, o quanti secondi senza audio quando si è fermato); a ogni perdita e a ogni ritorno del microfono e dell'audio di sistema. Le righe del registro di macOS restano come sono. Nulla è scritto da un thread audio.
      - Il registro offre alle altre parti dell'app un modo unico per scrivere una riga di un'area; il rilevamento delle app di call (area `detection`) e la lettura di Teams (area `teams`) lo usano nei loro Task.
      - Il README spiega dove si trova il registro (anche visibile nell'app Console), cosa scrive ogni area, e come avviare lo script di verifica di Teams e quale permesso serve al Terminale.

      Il motivo dei riavvii del microfono va scritto anche dopo che il microfono passerà alla cattura solo ingresso con Core Audio (Task del Microfono): i motivi elencati restano gli stessi.

      ## Code notes

      Commit: 09822d2c2cd4d67434f3e6f8e5dbb2030694288a

      - Unico helper di log oggi: `Sources/LARP/Recording/CaptureLog.swift` (`CaptureLog`, `BufferDrops`, `TrackStats`), `Logger(subsystem: "com.larp.LARP", category: "capture")` a livello `.info`; `systemAudioStarted`, `microphoneStarted`, `trackStopped`. `TrackPipeline` riusa `CaptureLog.logger`. Il sottosistema `"com.larp.LARP"` è scritto a mano in 16 file: una costante condivisa aiuta.
      - Convenzione: `private static let logger` per tipo, interpolazioni `privacy: .public`. Nessun test controlla l'output di `Logger`.
      - Riavvii microfono: `Sources/LARP/Recording/MicrophoneCapture.swift` `restart(_:)` con `Trigger` (`.configurationChange`, `.devicesChanged`, `.choice`); `restart` gira sotto `lock`: scrivere dopo il lock, come fa `events`.
      - Audio di sistema: `Sources/LARP/Recording/SystemAudioTap.swift` (`defaultStallTimeout = 2`, `checkStall`, `restart`, `heartbeat.secondsSinceLast()` per i secondi senza audio); `Sources/LARP/Recording/CoreAudioSystemDriver.swift` `CoreAudioSystemCapture.propertiesChanged` confronta `Signature`: per il motivo serve sapere quale campo differisce. `devicesChanged` unisce le raffiche tramite `changePending`: scrivere il motivo al trigger e l'esito in `restart()`.
      - Fine registrazione: `Sources/LARP/Recording/CallAudioCapture.swift` `stop()` chiama `trackStopped`.
      - L'I/O proc non deve scrivere, bloccare o allocare: continuare a contare con `BufferDrops`.
      - Insidia: `.private` finisce comunque nel registro di macOS come `<private>`; i testi di Teams non vanno mai passati al logger.
      - Il README oggi non ha alcuna sezione sui registri.
---
# Microfono solo ingresso e registro diagnostico

La cattura del microfono usa un'unità HAL di sola ingresso al posto di AVAudioEngine: si riapre solo se cambia il microfono da usare, il suo formato o se sparisce, mentre un cambio della sola uscita crea un nuovo cancellatore d'eco senza buchi. Ogni avvio, riavvio, motivo del riavvio, perdita e ritorno del microfono viene scritto nel registro diagnostico, area capture.
