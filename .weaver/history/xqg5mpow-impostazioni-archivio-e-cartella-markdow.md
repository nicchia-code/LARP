---
created: 2026-11-11T16:47:46.925Z
updated: 2026-11-11T17:46:39.636Z
summary: Pagina Impostazioni a card, finestra di benvenuto, conservazione dell'audio e cartella Markdown.
tasks:
- yi6xuzas
- 71v5dfcn
- w06newey
- kwjpifuv
- jjtmw8ac
cleared:
  yi6xuzas:
    title: Pagina delle Impostazioni
    refs:
    - settings
    - launch-at-login
    - assistant-status
    - requirements/ui#settings
    - requirements/rules#launch-at-login
    - user.OPEN_SETTINGS
    technical: false
    proposal: skvedwa5
    label: Redesign
    finished: 2026-11-11T15:57:38.000Z
    body: |-
      Le Impostazioni lasciano la loro finestra e diventano una pagina della finestra principale, con il nuovo linguaggio visivo. La schermata della Style Guide (06 Settings) è allegata a questo Task.

      ## Cosa deve valere alla fine

      - `user.OPEN_SETTINGS` (da "Impostazioni" della finestra a comparsa, della barra laterale o con ⌘,) porta l'app in primo piano e mostra la finestra principale sulle Impostazioni; se una call era mostrata, la pagina viene lasciata e il suo audio scaricato.
      - La barra laterale mostra "‹ Archivio" in alto e i nomi delle sezioni; il clic su un nome porta in vista la sua sezione, e quella scelta è disegnata come l'elemento scelto dell'Archivio.
      - La pagina ha l'eyebrow "Impostazioni", il titolo "Fallo tuo." e le sezioni come card bianche in due colonne (una sotto i 900 px); ogni riga ha etichetta, spiegazione facoltativa e il controllo a destra.
      - **Trascrizione**: "Motore" con il solo valore "Sul Mac" come segmento ink selezionato e "L'audio non lascia il computer" (la trascrizione cloud non si sviluppa); "Lingua" Italiano / English con lo stato del modello vocale ("Verifica in corso…", "Download in corso…", "Non disponibile, nuovo tentativo appena possibile", "Pronta") e "Vale per le registrazioni che iniziano dopo la scelta."; "Rifinisci il testo con omp" con uno switch.
      - **Sintesi**: "Sintetizza quando la call finisce" con uno switch e "Sintesi, decisioni e prossimi passi scritti da omp".
      - Sotto ogni interruttore di omp acceso compare lo stato di omp: "Verifica in corso…", "omp pronto" o "omp non trovato" (in `#B42A18`); omp si cerca solo mentre almeno uno dei due è acceso e conta solo l'ultimo controllo.
      - **Scorciatoie**: "Apri LARP all'accesso" con uno switch e "Resta discreto nella barra dei menu"; lo switch appare acceso quando l'elemento di login è attivo o in attesa di approvazione, e in attesa compare "Approva LARP in Impostazioni di Sistema › Generali › Elementi login.". Se registrare o togliere fallisce compare "Impossibile cambiare l'avvio all'accesso: <errore>" (inglese "Couldn't change opening at login: <error>") in `#B42A18` e lo stato reale si rilegge.
      - Ogni scelta resta tra un avvio e l'altro; il comportamento delle impostazioni non cambia.

      ## Code notes
      Commit: 58d947126f08b8c7e4128d08782a627080bde977
      - `Sources/LARP/Settings/SettingsView.swift` (`.formStyle(.grouped)`, `.frame(width: 440)`, `statusText`, `assistantText`): da rifare come pagina. Prende `LaunchAtLogin` come `@State`, non condiviso.
      - `Sources/LARP/App/LARPApp.swift`: scena `Settings { SettingsView() }` da togliere; ⌘, deve aprire la finestra principale. `init()` collega `start`/`appLaunched`.
      - `Sources/LARP/App/MenuBarContent.swift`: `SettingsLink` con `NSApp.activate()` (serve per app agent).
      - `Sources/LARP/Settings/AssistantStatusController.swift` `openSettings()`, `appLaunched()`; `TranscriptionLanguageController.swift` (contatore `generation`, `evaluate()`); `TranscriptRefinementController.swift`, `CallSummariesController.swift`; `LaunchAtLogin.swift` (`LoginItem`, `MainAppLoginItem`).
      - Macchine `@MainActor @Observable final class` con `static let shared`, dipendenze dietro protocolli; test in `Tests/LARPTests/LaunchAtLoginTests`, `TranscriptionLanguageTests` (`FakeLoginItem`, `makeDefaults()`).
  71v5dfcn:
    title: Conservazione dell'audio
    refs:
    - audio-retention
    - call
    - playback
    - time.AUDIO_RETENTION_CHECK_DUE
    - requirements/rules#audio-retention
    - requirements/tech#audio-retention
    - requirements/data#call
    - user.CHOOSE_AUDIO_RETENTION
    technical: false
    proposal: c36rrzca
    label: 'Redesign: file e archivio'
    finished: 2026-11-11T16:34:05.865Z
    body: |-
      L'utente sceglie per quanto tempo si tiene l'audio delle call: "Sempre" (default), "Per 30 giorni" o "Per 90 giorni", contati dall'inizio di ogni call; un giorno vale 24 ore. Scaduto il tempo, i file audio di una call pronta si cancellano dal Mac; trascrizione, sintesi, note, segnalibri e forma d'onda restano, e la call non si può più ascoltare.

      ## Cosa deve valere

      - **Tieni sempre** (iniziale, salvo che sia stato scelto un limite): l'audio resta finché la call non viene eliminata.
        - Scegliendo 30 o 90 giorni la scelta è salvata, si passa a **Tieni per un tempo** e l'audio delle call pronte più vecchie viene cancellato subito; scegliendo "Sempre" non cambia nulla.
      - **Tieni per un tempo**: scegliendo l'altro numero di giorni la scelta è salvata e l'audio delle call pronte più vecchie del nuovo limite viene cancellato subito; scegliendo "Sempre" la scelta è salvata e l'audio già cancellato non torna.
      - Il controllo avviene all'avvio, dopo che ogni altro lavoro dell'avvio è partito, poi ogni ora mentre l'app è aperta, e subito dopo una nuova scelta. Per ogni call vale solo se: l'audio è tenuto per un tempo limitato, la call è nello stato Ready, è iniziata da più di quel tempo, ha ancora il suo audio e la sua sintesi non è in scrittura. Una call saltata viene guardata di nuovo al controllo successivo.
      - Si cancellano solo i due file audio della call (microfono e audio di sistema), mai altro contenuto della sua cartella; la call resta Ready e conserva che il suo audio è stato rimosso, con il numero di giorni in vigore in quel momento.
      - Una call con l'audio rimosso: la forma d'onda non cambia; non si può riprodurre né le si può aggiungere un segnalibro ascoltando; la barra di riproduzione dice "Audio eliminato dopo <n> giorni" al posto di "Audio non disponibile", con <n> i giorni della conservazione in vigore quando fu rimosso. La riproduzione resta ferma: avviarla, cliccare una frase, un segnalibro o una decisione non la fa partire.
      - Dati: l'impostazione dei giorni di conservazione vale 30 o 90; assente significa "Sempre" e ogni altro valore si legge come "Sempre". Il segno di audio rimosso con i giorni è un campo opzionale della call (default no), così uno store salvato prima si apre senza.
      - Tecnica: il controllo orario gira su un timer dell'app mentre è aperta; i file si rimuovono con il file manager dell'archivio, fuori dal thread principale, e il segno sulla call è salvato sul thread principale.
      - La scelta "Conserva i file audio" nella pagina Impostazioni è nella Task "Privacy e archivio"; qui servono la scelta salvata e il comportamento.

      ## Code notes
      Commit: 58d947126f08b8c7e4128d08782a627080bde977
      - Call: `Sources/LARP/Call/CallStateMachine.swift` (`CallStateMachine.target`, `CallEvent`: tabella pura, gli eventi portano i fatti delle guardie); effetti in `Sources/LARP/Call/CallLifecycle.swift` (`apply(_:to:)`, `enter(_:call:)`); avvio cablato in `Sources/LARP/App/LARPApp.swift` `init()` (start/appLaunched).
      - Stato sintesi: `Sources/LARP/Model/SummaryState.swift`. Dati: `Sources/LARP/Model/Call.swift` (percorsi audio relativi), `Sources/LARP/Model/AppPaths.swift`, `ArchiveStore.swift`. Nuovi campi SwiftData con default (come `summaryStateRawValue`); valori grezzi sconosciuti ricadono su un default.
      - Chiavi: `Sources/LARP/Settings/SettingsKey.swift`; controller come gli altri in `Sources/LARP/Settings/` (`@MainActor @Observable`, `static let shared`, dipendenze dietro protocolli).
      - Riproduzione: `Sources/LARP/Playback/PlaybackController.swift` (`show`, `seek`, `play(fromSentenceStart:)`), `PlaybackControlsView.swift` per il testo della barra.
      - Il lavoro sul Model avviene sul main actor; le dipendenze esterne (file manager, timer) dietro protocolli con fake in `Tests/LARPTests/CallLifecycleFakes.swift`. Test pertinenti: `CallManagementTests`, `ArchiveStoreTests`.
  w06newey:
    title: Cartella Markdown
    refs:
    - markdown-folder
    - requirements/rules#markdown-folder
    - requirements/tech#markdown-folder
    - user.TURN_ON_MARKDOWN_FOLDER
    - user.CHOOSE_MARKDOWN_FOLDER
    - user.TURN_OFF_MARKDOWN_FOLDER
    technical: false
    proposal: c36rrzca
    label: 'Redesign: file e archivio'
    finished: 2026-11-11T16:44:58.939Z
    body: |-
      Ogni call pronta può essere tenuta come file Markdown, uno per call, in una cartella scelta dall'utente, con lo stesso contenuto dell'esportazione Markdown. I file si scrivono solo sul Mac. La funzione è spenta di default.

      ## Cosa deve valere

      - **Off** (iniziale, salvo che la cartella sia rimasta accesa): nessun file viene scritto; i file scritti prima restano dove sono.
        - Accendendo "Cartella Markdown" si apre il pannello di sistema per scegliere una cartella: scelta una cartella, la scelta è salvata, si passa a On e tutte le call pronte vengono scritte subito; annullando il pannello resta Off.
      - **On**:
        - Scegliendo un'altra cartella ("Cambia"), la scelta è salvata, i file nella cartella precedente restano dove sono e tutte le call pronte vengono scritte subito nella nuova.
        - Spegnendo, la scelta è salvata e si passa a Off; i file scritti restano.
        - Quando una call diventa pronta il suo file viene scritto, sostituendo quello che aveva.
        - Il file viene riscritto, solo per una call pronta, quando: la sintesi viene scritta; un partecipante viene rinominato; una riga viene corretta; la trascrizione viene ripristinata; un'azione viene spuntata o tolta; una nota viene aggiunta, modificata o cancellata; un segnalibro viene aggiunto o cancellato.
        - Rinominando una call pronta il file prende il nuovo nome e quello con il vecchio nome viene rimosso.
        - Quando una call viene eliminata il suo file viene rimosso dalla cartella.
      - Una call conta come pronta per la cartella solo quando è nello stato Ready; in ogni altro stato viene scritta quando diventa pronta.
      - Nome del file: come il nome predefinito dell'esportazione con `.md` aggiunto; quando un'altra call della cartella usa già quel nome si aggiunge " (2)", " (3)" e così via prima di `.md`. Il nome usato da ogni call è conservato con la call (assente finché non è scritto), per poterlo rinominare o rimuovere; un file non viene mai rimosso né rinominato se non è stato scritto da LARP per quella call.
      - Contenuto: l'esportazione Markdown della call, nella lingua dell'interfaccia al momento della scrittura.
      - Quando un file non si può scrivere si riprova al cambio successivo di quella call; la cartella resta accesa e le Impostazioni mostrano "Impossibile scrivere nella cartella" sotto la riga finché una scrittura non riesce.
      - La cartella si sceglie con il pannello di apertura di sistema; il percorso è conservato così com'è (l'app non è sandboxed) nell'impostazione della cartella Markdown, la cui assenza significa spenta. I file si scrivono in modo atomico, fuori dal thread principale, una call alla volta, in UTF-8.
      - Fanno parte di questa Task il salvataggio dell'impostazione e il campo con il nome del file della call; la riga "Cartella Markdown" della pagina Impostazioni (interruttore, percorso, "Cambia", messaggio d'errore) è nella Task "Privacy e archivio", che ne mostra lo stato.

      ## Code notes
      Commit: 58d947126f08b8c7e4128d08782a627080bde977
      - Contenuto e nome: `Sources/LARP/Archive/TranscriptExport.swift` (`TranscriptExport.markdown(for:)`, `defaultFileName`, `ArchiveFormat`), `MarkdownDocument.swift`; `SummaryContent` è l'unica fonte della sintesi per vista, ricerca ed export: estenderla, non duplicarla.
      - Chiavi: `Sources/LARP/Settings/SettingsKey.swift`; controller come gli altri in `Sources/LARP/Settings/` (`@MainActor @Observable final class` con `static let shared`, dipendenze dietro protocolli con `@ObservationIgnored`, un metodo per evento del Model con doc comment che nomina evento e transizione; tabella di transizione pura).
      - Eventi della call: `Sources/LARP/Call/CallLifecycle.swift` (`enter(_:call:)`, `renameCall`, `renameParticipant`, `delete`), `CallLifecycle+Refinement.swift`, `CallLifecycle+Summary.swift`. Settings non dipende dallo strato call: il cablaggio è in `Sources/LARP/App/LARPApp.swift` `init()`. Notizie tra parti via `EventBroadcaster<T>`.
      - Dati: `Sources/LARP/Model/Call.swift`; i nuovi campi SwiftData devono avere un default (come `summaryStateRawValue`) per aprire store vecchi.
      - Test: `UserDefaults` iniettato con suite isolate (`makeDefaults()`), suite Swift Testing `.serialized`; fake come in `Tests/LARPTests/CallLifecycleFakes.swift`.
  kwjpifuv:
    title: Privacy e archivio
    refs:
    - settings
    - main-window
    - requirements/ui#settings
    - requirements/data#settings
    - requirements/tech#main-window
    - user.REVEAL_ARCHIVE
    technical: false
    proposal: c36rrzca
    label: 'Redesign: file e archivio'
    finished: 2026-11-11T17:30:53.969Z
    body: |-
      La pagina Impostazioni della finestra principale mostra la sezione "Privacy e archivio" e, nella sezione "Esportazione e integrazioni", la riga "Cartella Markdown", collegate alla conservazione dell'audio e alla cartella Markdown.

      ## Cosa deve valere

      - Sezione **Privacy e archivio**, card bianca con titolo come le altre sezioni, righe separate da divisori `#E4E4DC`:
        - "Conserva i file audio" con la scelta "Sempre", "Per 30 giorni", "Per 90 giorni" e la spiegazione "Trascrizioni e sintesi restano"; la scelta mostra il valore salvato (assente o sconosciuto si mostra "Sempre") e cambiarla è la scelta della conservazione dell'audio.
        - "Posizione dell'archivio" con il percorso dell'archivio sotto, in JetBrains Mono 11 px `#5A5D55`, accorciato con "~", e il bottone outline "Mostra nel Finder". La posizione è solo mostrata, non si può cambiare.
      - "Mostra nel Finder": la pagina resta sulle Impostazioni e il Finder si apre selezionando la cartella `LARP` di Application Support, cioè la cartella dell'archivio.
      - In **Esportazione e integrazioni**, prima di "Calendario", la riga "Cartella Markdown" con un interruttore e la spiegazione "Salva ogni sintesi e trascrizione come file .md"; mentre è accesa mostra il percorso della cartella in JetBrains Mono 11 px `#5A5D55`, il bottone outline "Cambia" e, quando una scrittura è fallita, "Impossibile scrivere nella cartella" in `#B42A18` finché una scrittura non riesce. Accendere l'interruttore apre la scelta della cartella (annullando resta spento), "Cambia" sceglie un'altra cartella, spegnere lo spegne.
      - Le altre sezioni e righe restano come nelle Proposal precedenti; nella barra laterale delle Impostazioni il nome "Privacy e archivio" porta in vista la sezione.
      - Non vanno sviluppati "Elimina tutte le registrazioni" né integrazioni con Notion, Slack o email.

      ## Code notes
      Commit: 58d947126f08b8c7e4128d08782a627080bde977
      - Pagina: `Sources/LARP/Settings/SettingsView.swift` (oggi `.formStyle(.grouped)`, `.frame(width: 440)`; le Proposal precedenti la portano nella finestra principale con le card), `statusText`, `assistantText`. `SettingsView` prende `LaunchAtLogin` come `@State`, non condiviso.
      - Percorso archivio: `Sources/LARP/Model/AppPaths.swift` (radice statica), `ArchiveStore.makeContainer`.
      - Ogni effetto di UI passa per un presenter/protocollo `@MainActor` sostituibile nei test: mettere l'apertura del Finder (`NSWorkspace.activateFileViewerSelecting`) dietro un protocollo con fake.
      - I commenti nel codice citano gli eventi del Model (es. `user.REVEAL_ARCHIVE`); i testi sono in italiano con il String Catalog it/en.
      - Wiring dei controller in `Sources/LARP/App/LARPApp.swift` `init()`.
  jjtmw8ac:
    title: 'Fix the code: File Markdown sovrascritto'
    refs:
    - markdown-folder/On
    technical: false
    finished: 2026-11-11T17:42:55.538Z
    body: |-
      ## What happens

      Quando la cartella Markdown contiene già un file con lo stesso nome della call (per esempio un `Weekly.md` scritto dall'utente, o un file lasciato da una cartella spenta e riaccesa), la scrittura lo **sostituisce** senza avvisare. Il numero " (2)", " (3)" si aggiunge solo quando un'altra call della cartella usa già quel nome.

      ## What should happen

      Il Model dice che un file non viene mai rimosso né rinominato se non è stato scritto da LARP per quella call, ma tace sul caso di un file estraneo con lo stesso nome: cosa fare cambia quali dati dell'utente restano.

      ## Chosen option

      ### Ricordare i file scritti da LARP

      LARP conserva per ogni cartella i nomi che ha scritto e li sostituisce soltanto; un file con un nome non suo viene aggirato con " (2)". Riaccendendo la stessa cartella i vecchi file si riconoscono e si riscrivono. Costo: un elenco in più da salvare e tenere coerente.

      ## Where in the code

      Sources/LARP/Call/MarkdownFolderSync.swift, scelta del nome (`fileName(for:language:)`) e scrittura atomica del file
---
# Impostazioni, archivio e cartella Markdown

Sezioni delle Impostazioni nella finestra principale, benvenuto con permessi e scelte, eliminazione dell'audio dopo 30 o 90 giorni, scrittura dei file Markdown per call. La riga Cartella Markdown nelle Impostazioni resta nel Task Privacy e archivio, bloccato da una Drift.
