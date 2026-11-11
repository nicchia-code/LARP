---
created: 2026-11-11T16:47:46.895Z
updated: 2026-11-11T17:46:48.075Z
summary: Recorder con proposta scartabile, pausa e registrazione automatica; popover, pillola, finestra dal vivo, microfono scelto e scorciatoie globali.
tasks:
- k20u5oxw
- 9dasa2ti
- tadc4cvk
- u8781e9v
- znxx3skh
cleared:
  k20u5oxw:
    title: Popover e proposta
    refs:
    - recorder
    - capture
    - requirements/ui#recorder
    - requirements/rules#recorder
    - user.START_RECORDING
    - user.ACCEPT_PROPOSAL
    - user.STOP_RECORDING
    technical: false
    proposal: skvedwa5
    label: Redesign
    finished: 2026-11-11T15:54:35.494Z
    body: |-
      Ridisegna l'icona della barra dei menu, la finestra a comparsa, la proposta di registrare e gli avvisi del Recorder con il nuovo linguaggio visivo. Le schermate della Style Guide (02 barra dei menu) sono allegate a questo Task.

      ## Cosa deve valere alla fine

      - L'icona della barra dei menu è il marchio LARP colorato fuori da una registrazione; durante una registrazione resta il punto rosso `#FF5A40` seguito dal tempo trascorso, aggiornato ogni secondo, in cifre di larghezza uguale (`m:ss`, `h:mm:ss` da un'ora in su; torna a zero alla fine).
      - Il clic sull'icona apre una finestra a comparsa scura al posto del menu, 340 px, ink, raggio 18: in alto il marchio LARP con "LARP" e lo stato a destra ("Pronto quando vuoi", "Call rilevata", "In registrazione"); poi la card dello stato; in fondo, dopo un divisore, "Apri archivio" a sinistra e "Impostazioni" ed "Esci" a destra. "Esci" chiude l'app.
      - In Idle la card dice "Registrazione manuale", "Nessuna call in corso" e offre "Registra" (lime, a tutta larghezza): `user.START_RECORDING` avvia la registrazione solo con il permesso del microfono (chiesto se non ancora deciso; l'audio di sistema non si controlla), legata a nessuna app; se manca, nulla si registra e compare l'avviso di sistema del permesso mancante.
      - Quando un'app di call conosciuta inizia a usare il microfono compare la proposta, una card scura identica ovunque: "In onda ora · <app di call>" con il punto rosso, "Call rilevata" e il pulsante lime "Registra questa call". Resta nel pannellino sotto l'icona che non prende mai il focus, prende il posto della card della finestra a comparsa e compare come banner in cima all'Archivio. Non si può scartare: resta finché viene accettata o l'app smette di usare il microfono; non c'è mai una seconda proposta.
      - `user.ACCEPT_PROPOSAL` richiede microfono e audio di sistema, controllati in quest'ordine e detto solo il primo mancante; la proposta scompare ovunque. Con i permessi la registrazione è legata all'app della proposta (anche se nel frattempo ha smesso, allora legata a nessuna app); senza, compare l'avviso del permesso mancante.
      - Durante una registrazione la card mostra "In registrazione" con il punto rosso, il titolo della call, il tempo trascorso in JetBrains Mono e il pulsante bianco "Ferma registrazione" con un quadrato ink; `user.STOP_RECORDING` la termina, ogni avviso della registrazione scompare e il tempo torna a zero. Le azioni di pausa e finestra dal vivo arrivano con la Proposal sulla registrazione.
      - Gli avvisi sotto l'icona (eco non rimossa, audio di sistema non disponibile, microfono perso, audio di sistema perso) sono card ink 300 px, testo bianco con icona rossa per le perdite e lime per le informazioni, pulsante outline su scuro per aprire Impostazioni di Sistema; tempi e impilamento come nella Requirement. Gli avvisi di permesso mancante o di registrazione non avviata restano avvisi di sistema, con i testi italiani e inglesi della Requirement.
      - Il resto del comportamento del Recorder e della cattura non cambia.

      ## Code notes
      Commit: 58d947126f08b8c7e4128d08782a627080bde977
      - `Sources/LARP/App/MenuBarContent.swift` `MenuBarContent` (menu di oggi) e `LARPApp.body` in `Sources/LARP/App/LARPApp.swift`: il menu diventa finestra a comparsa.
      - `Sources/LARP/Capture/MenuBarLabel.swift` `MenuBarLabel`, `recordingDot` (NSImage non template).
      - `Sources/LARP/Capture/RecorderPresenters.swift`: `ProposalPanelController`, `MenuBarPanel` (creazione NSPanel, `origin(for:below:)`, pila), `ProposalView`/`NoticeView`/`EchoCancellationWarningView` con sfondi `.regularMaterial` da sostituire. `MenuBarPanel` trova lo status item con `className.contains("StatusBar")`: fragile.
      - `Sources/LARP/Capture/Recorder.swift`: `Recorder` `@Observable` (`state`, `elapsedSeconds` letti direttamente), `.proposing`, `acceptProposal`, `startRecording`.
      - `Sources/LARP/Capture/SystemRecordingPermissions.swift` `missingPermission(requireSystemAudio:)`.
      - Ogni effetto UI passa da un presenter `@MainActor` dietro protocollo sostituito nei test; mantenere i riferimenti agli eventi del Model nei commenti.
      - App `LSUIElement`: `NSApp.activate()` prima di `openWindow`/aprire le Impostazioni.
  9dasa2ti:
    title: Microfono scelto
    refs:
    - microphone
    - microphone-choice
    - requirements/rules#microphone
    - requirements/tech#microphone
    - user.CHOOSE_MICROPHONE
    technical: false
    proposal: sbjz6djo
    label: 'Redesign: registrazione'
    finished: 2026-11-11T15:55:10.516Z
    body: |-
      L'utente sceglie quale microfono registrare, nelle Impostazioni (riga "Microfono" della sezione Registrazione) e nella finestra a comparsa.

      ## Cosa deve valere

      - La scelta offre "Predefinito di sistema" (il default) e i dispositivi di ingresso collegati ora, più quello scelto, mostrato "<nome> (non collegato)", quando manca.
      - **Predefinito di sistema**: si registra il microfono predefinito del Mac, seguito quando cambia. **Microfono scelto**: si registra il dispositivo scelto, riconosciuto dal suo identificatore univoco, quando è collegato; quando non lo è, al suo posto il predefinito. Il microfono scelto torna in uso da solo quando viene ricollegato (assunzione dell'agente).
      - Ogni scelta diversa è salvata; scegliere di nuovo "Predefinito di sistema" quando già lo è non cambia nulla.
      - Una scelta durante la registrazione cambia subito microfono, solo se il microfono da usare cambia: la cattura riparte su di esso come per un cambio di dispositivi, il vuoto è riempito di silenzio nella traccia e, mentre l'audio di sistema è catturato, un nuovo cancellatore d'eco impara il percorso da capo. Se riparte senza audio di sistema o senza cancellatore si registra com'è; senza cancellatore l'utente è avvisato per 10 secondi di usare le cuffie. Se non può partire, il microfono è perso e compare l'avviso duraturo che il microfono non è disponibile.
      - Dallo stato perso, ogni cambio dei dispositivi collegati o del microfono da usare è un'occasione per ripartire: se riparte il vuoto è riempito di silenzio e l'avviso sparisce; se no non si dice nulla.
      - Tutto il resto della cattura resta com'è: avvio dopo l'audio di sistema, niente elaborazione vocale di macOS, cancellatore AEC3 solo, nuovo motore a ogni avvio con il formato riportato in quel momento.
      - Salvataggio: `settings.microphone` con l'identificatore univoco del dispositivo come lo riporta Core Audio e `settings.microphoneName` con il nome per quando non è collegato; assente vale "Predefinito di sistema".

      ## Code notes
      Commit: 58d947126f08b8c7e4128d08782a627080bde977
      - `Sources/LARP/Recording/MicrophoneEngine.swift` `AVMicrophoneEngine`: il dispositivo scelto si imposta come current device sull'audio unit dell'input node; frequenza zero o nessun canale = nessun microfono.
      - `Sources/LARP/Recording/MicrophoneCapture.swift` `MicrophoneCapture`: listener sul dispositivo predefinito; aggiungere quello sulla lista dei dispositivi perché il microfono scelto ricollegato venga ripreso. I listener girano su una coda privata e vanno rimossi fuori dal lock del microfono; le notifiche di configurazione di un motore già sostituito si ignorano.
      - `Sources/LARP/Recording/CallAudioCapture.swift`, `TrackPipeline.swift` `fillSilence` per il vuoto.
      - Avvisi: `Sources/LARP/Capture/RecorderPresenters.swift` (`MenuBarPanel`, notice controllers). Riga nella finestra a comparsa: `Sources/LARP/App/MenuBarContent.swift`; impostazioni `Sources/LARP/Settings/SettingsView.swift`; chiavi `SettingsKey.swift`.
      - Il motore sta dietro un protocollo con dispositivi finti nei test; i test di hardware hanno il tag `requiresHardware`.
      - Convenzione: controller `@MainActor @Observable final class` con `static let shared`, `UserDefaults` iniettato.
  tadc4cvk:
    title: Proposta, pausa, auto-registrazione
    refs:
    - recorder
    - capture
    - call-detection
    - auto-recording
    - requirements/rules#recorder
    - requirements/tech#recorder
    - requirements/ui#recorder
    - requirements/data#capture
    - user.START_RECORDING
    - user.ACCEPT_PROPOSAL
    - user.DISMISS_PROPOSAL
    - user.STOP_RECORDING
    - user.PAUSE_RECORDING
    - user.RESUME_RECORDING
    - user.TURN_ON_CALL_DETECTION
    - user.TURN_OFF_CALL_DETECTION
    - user.WATCH_APP
    - user.UNWATCH_APP
    - user.TURN_ON_AUTO_RECORDING
    - user.TURN_OFF_AUTO_RECORDING
    technical: false
    proposal: sbjz6djo
    label: 'Redesign: registrazione'
    finished: 2026-11-11T16:23:17.481Z
    body: |-
      Il Recorder segue il nuovo Model: rilevamento delle call con app sorvegliate, proposta scartabile con "Non questa", registrazione automatica e pausa.

      ## Cosa deve valere

      - **Rilevamento**: una call app che inizia a usare il microfono dà una proposta o una registrazione automatica solo se "Rileva le call" (Call detection) è acceso e l'app è sorvegliata. Ogni app nota è sorvegliata finché l'utente non spegne il suo chip; la scelta di ogni app resta salvata anche a rilevamento spento. Rilevamento acceso di default.
        - Spegnendo il rilevamento la scelta viene salvata, la proposta mostrata (anche quella scartata) sparisce e non partono nuove proposte né registrazioni automatiche; una registrazione in corso continua. Riaccendendolo, le app sorvegliate che già usano il microfono contano come avviate.
        - Sorvegliare un'app a rilevamento acceso: se già usa il microfono conta come avviata. Smettere di sorvegliarla: la proposta mostrata o scartata per quell'app sparisce (assunzione dell'agente: come spegnere il rilevamento), la registrazione in corso continua. A rilevamento spento, il cambio di un chip è solo salvato.
      - **Registrazione automatica** ("Registra automaticamente le call rilevate", spenta di default): se accesa e i permessi del microfono e dell'audio di sistema sono già concessi (letti senza chiedere), la call rilevata viene registrata senza proposta, legata alla call app; se un permesso non è ancora concesso compare la proposta. Accenderla lascia la proposta già mostrata; spegnerla lascia continuare la registrazione in corso. Si cambia dalle Impostazioni e dalla finestra a comparsa.
      - **Proposta**: card scura "In onda ora · <app>", titolo "Call rilevata", "Registra questa call" con la scorciatoia e "Non questa"; identica nel pannello sotto l'icona (che non prende mai il focus), nella finestra a comparsa al posto della card dello stato e come banner in cima all'Archivio. Mai una seconda proposta.
      - **"Non questa"** (DISMISS_PROPOSAL): la proposta sparisce ovunque, niente viene registrato; lo stato "Proposal dismissed" conta come l'unica proposta finché quell'app non smette di usare il microfono, e la finestra a comparsa appare come a riposo ("Pronto quando vuoi"). Se poi l'utente avvia la registrazione ("Registra", "Nuova registrazione" o la scorciatoia) mentre l'app usa ancora il microfono, servono entrambi i permessi, come accettando la proposta, e la registrazione è legata a quell'app; con un permesso mancante l'avviso nomina il primo mancante, microfono prima.
      - **Pausa**: "Pausa"/"Riprendi" dalla pillola, dalla finestra dal vivo e dalla finestra a comparsa. In pausa entrambe le tracce si scrivono con silenzio della stessa lunghezza dell'audio catturato, la trascrizione dal vivo riceve lo stesso silenzio, il tempo trascorso continua a contare (i tempi della call restano quelli dell'orologio), i livelli sono vuoti. L'icona della barra dei menu mostra il punto `#A3A69B` invece di `#FF5A40`, la finestra a comparsa dice "In pausa". Una call app legata che smette di usare il microfono termina la registrazione anche in pausa.
      - **Finestra a comparsa**: stato "Pronto quando vuoi" / "Call rilevata" / "In registrazione" / "In pausa"; durante la registrazione titolo, tempo, "Pausa"/"Riprendi", "Ferma registrazione" e "Apri finestra dal vivo"; righe "Audio della call" (app della registrazione o della proposta, "—" altrimenti), "Microfono" e l'interruttore della registrazione automatica. "Ferma e sintetizza" non va sviluppato: resta "Ferma".
      - Non sviluppato: il promemoria del consenso.
      - Le scelte sono salvate in `settings.callDetection` (default sì), `settings.unwatchedCallApps` (nomi delle app spente; nomi non più noti ignorati) e `settings.autoRecording` (default no). Nulla del Recorder è salvato.

      ## Code notes
      Commit: 58d947126f08b8c7e4128d08782a627080bde977
      - `Sources/LARP/Capture/Recorder.swift`: `Recorder` (`handle`, `startMonitoring`, `.started` → `.proposing`, `acceptProposal`, `startRecording`, `beginRecording`, `endRecording`); `@Observable`, SwiftUI legge `state` ed `elapsedSeconds`. Serve uno stato per la proposta scartata e un sottostato di pausa.
      - `Sources/LARP/Capture/SystemRecordingPermissions.swift`: `missingPermission(requireSystemAudio:)`; per l'automatica serve una lettura senza chiedere.
      - `Sources/LARP/Capture/KnownCallApps.swift`: `KnownCallApps.all`, `app(forBundleIdentifier:in:)`; `CoreAudioCallAppMicSource.swift` `refresh()` per le app già attive.
      - `Sources/LARP/Capture/RecorderPresenters.swift`: `ProposalPanelController`, `MenuBarPanel`; `Sources/LARP/App/MenuBarContent.swift`, `Capture/MenuBarLabel.swift` (`recordingDot`).
      - Chiavi in `Sources/LARP/Settings/SettingsKey.swift`; controller come `@MainActor @Observable final class` con `static let shared`, dipendenze dietro protocolli, `UserDefaults` iniettato (test con `makeDefaults()`), una funzione per evento con commento che cita l'evento del Model.
      - Pausa: `Sources/LARP/Recording/TrackPipeline.swift` `process`, `fillSilence`; il silenzio va scritto sulla coda privata della traccia, mai dal thread audio.
      - Ogni effetto UI passa da un presenter `@MainActor` dietro protocollo, sostituito nei test.
  u8781e9v:
    title: Remove code of `recorder/Microphone lost`
    refs:
    - recorder/Recording
    technical: false
    proposal: sbjz6djo
    label: 'Redesign: registrazione'
    finished: 2026-11-11T16:23:17.521Z
    body: ''
  znxx3skh:
    title: 'Fix the code: Registrazione automatica senza chiedere il permesso audio'
    refs:
    - requirements/tech#recorder
    - requirements/rules#recorder
    - auto-recording
    technical: false
    finished: 2026-11-11T17:31:35.122Z
    body: |-
      ## What happens

      Per decidere se registrare da sola, la registrazione automatica legge il permesso dell'audio di sistema **senza chiedere** tramite un controllo privato del database dei permessi di macOS, non documentato e mai provato su un Mac reale. Se il controllo non è raggiungibile, il permesso conta come non concesso e compare la proposta.

      ## What should happen

      I Requirements dicono che il permesso dell'audio di sistema si verifica creando e distruggendo subito un tap di processo globale privato, e che la registrazione automatica richiede entrambi i permessi già concessi, letti **senza chiedere**. Il tap, la prima volta, fa comparire la richiesta di macOS: le due regole non si possono rispettare insieme con un controllo solo, e il Requirement non indica quale scelta di costruzione valga per la lettura senza richiesta.

      ## Chosen option

      ### Ricordare in memoria un tap riuscito

      La registrazione automatica parte solo se il microfono è concesso e, in questo avvio dell'app, un tap di sistema è già riuscito (per esempio accettando una proposta). Altrimenti compare la proposta. Nessuna richiesta a sorpresa e nessuna API privata; costo: la prima call dopo ogni avvio passa dalla proposta.

      ## Where in the code

      Sources/LARP/Capture/SystemRecordingPermissions.swift (lettura senza chiedere); Sources/LARP/Capture/Recorder.swift (registrazione automatica alla partenza di una call)
---
# Registrazione, popover e scorciatoie

Rilevamento con app sorvegliate, stato Non questa, pausa, popover scuro con proposta, pillola e finestra dal vivo con livelli, scelta del microfono che riavvia la cattura, scorciatoie Carbon modificabili; rimosso il codice dello stato di microfono perso.
