---
created: 2026-11-11T16:47:53.218Z
updated: 2026-11-11T17:46:47.939Z
summary: La finestra dell'archivio diventa la finestra principale con linguaggio visivo condiviso, interfaccia it/en, card, pagina della call, cartelle, filtri, import, segnalibri e note.
tasks:
- g3weoc3g
- r33eyxmx
- uykih1ia
- brxamt49
- lx995rnh
- dh44kade
- gbudpd9t
cleared:
  g3weoc3g:
    title: Remove code of `main-window/Call selected`
    refs:
    - main-window/Open
    technical: false
    proposal: skvedwa5
    label: Redesign
    finished: 2026-11-11T15:57:32.410Z
    body: ''
  r33eyxmx:
    title: Remove code of `main-window/No call selected`
    refs:
    - main-window/Open
    technical: false
    proposal: skvedwa5
    label: Redesign
    finished: 2026-11-11T15:57:34.816Z
    body: ''
  lx995rnh:
    title: Schede della call e Segnalibri
    refs:
    - main-window
    - playback
    - requirements/ui#main-window
    - requirements/ui#playback
    - user.SELECT_BOOKMARK
    - user.SHOW_ALL_CALLS
    - user.SHOW_BOOKMARKS_VIEW
    - user.SHOW_SUMMARY
    - user.SHOW_NOTES
    - user.SHOW_BOOKMARKS
    technical: false
    proposal: sbjz6djo
    label: 'Redesign: registrazione'
    finished: 2026-11-11T15:58:29.681Z
    body: |-
      La finestra principale guadagna la vista "Segnalibri" di tutte le call e le schede "Sintesi", "Le mie note" e "Segnalibri" nella pagina di una call.

      ## Cosa deve valere

      - **Barra laterale**: "Nuova registrazione" (lime, con la scorciatoia, disattivato al 40 % mentre qualcosa è proposto o registrato) avvia una registrazione a mano senza cambiare pagina; voci "Tutte le call" e "Segnalibri", la selezionata `#23251F` con testo lime.
      - **Archivio**: due viste, "Tutte le call" (iniziale, titolo "Tutto quello che è stato detto.") e "Segnalibri". La ricerca resta aprendo una call e tornando. Tornando da una call (con "‹ Archivio" o dopo l'eliminazione) l'Archivio riprende la vista da cui era stata aperta (assunzione dell'agente). Il banner "In onda ora" accetta o scarta la proposta.
      - **Vista Segnalibri**: i segnalibri delle call che corrispondono alla ricerca, raggruppati per call, call più recente prima e in ordine di tempo dentro una call; una card bianca per call con eyebrow (giorno, ora, app) e titolo, una riga per segnalibro con il tempo in un chip JetBrains Mono `#ECECE4` e il testo della riga di trascrizione a quel tempo, se c'è (al più due righe), evidenziata `#F1F1EA` sotto il puntatore. Senza segnalibri "Nessun segnalibro". SELECT_BOOKMARK apre la pagina della call sulla scheda Segnalibri, ne carica l'audio e lo riproduce dal segnalibro.
      - **Pagina della call**: si apre sulla Sintesi. Le schede in Bricolage Grotesque 18 px, la selezionata ink con sottolineatura lime di 3 px; "Sintetizza"/"Rigenera" a destra solo sulla Sintesi. Rinominare la call o un partecipante ed esportare lasciano la scheda com'era; annullare l'eliminazione torna sulla scheda mostrata prima.
        - **Le mie note**: una riga per nota con il tempo in un chip (nessuno senza tempo), testo modificabile sul posto, bottone elimina sotto il puntatore; in fondo il campo "Scrivi una nota…" che aggiunge con Invio. Senza note "Nessuna nota".
        - **Segnalibri**: una riga per segnalibro con tempo, testo della riga a quel tempo, elimina sotto il puntatore; un clic riproduce da lì. Senza segnalibri "Nessun segnalibro".
        - **Trascrizione**: la riga all'ora di un segnalibro porta "⌑ SEGNALIBRO" a destra dell'eyebrow.
      - **Riproduzione**: SELECT_BOOKMARK da fermo riproduce dal segnalibro se la call ha audio, caricandolo prima se non è quella mostrata; in riproduzione o in pausa riprende dal segnalibro. La barra ha un bottone tondo 36 px "Segnalibro" su `#2A2C26` che segna il tempo raggiunto; piccoli tick lime sopra la timeline segnano i segnalibri; senza audio "Audio non disponibile" con play e segnalibro disattivati. Durante la registrazione la barra non c'è.

      ## Code notes
      Commit: 58d947126f08b8c7e4128d08782a627080bde977
      - `Sources/LARP/Archive/ArchiveView.swift` `ArchiveView` (split view, ricerca, dialogo di eliminazione, `.callDeleted`); `CallDetailView.swift` (header, scheda, `show()`/`updateTimeline()`), è `.id(call.id)` quindi lo stato si azzera per call: la scheda iniziale per SELECT_BOOKMARK va passata da fuori.
      - `TranscriptView.swift` `TranscriptView`, `TranscriptLineRow`; `CallRow.swift`; `CallSearch.swift` `CallSearch.normalized`, `fields` per filtrare la vista Segnalibri.
      - Riproduzione: `Sources/LARP/Playback/PlaybackController.swift` (`show`, `setTimeline`, `seek`, `play(fromSentenceStart:)`), `PlaybackControlsView.swift`, `TranscriptTimeline.swift` `LineTiming` per trovare la riga a un tempo.
      - Avvio manuale: `Recorder.startRecording` in `Sources/LARP/Capture/Recorder.swift`.
      - Testi in italiano; commenti con gli eventi (`user.SELECT_CALL`); niente test UI, testare solo la logica (raggruppamento, ordine, ricerca) con Swift Testing.
  uykih1ia:
    title: Remove code of `main-window/Library/user.SELECT_CALL`
    refs:
    - main-window/Library
    technical: false
    proposal: sbjz6djo
    label: 'Redesign: registrazione'
    finished: 2026-11-11T16:02:41.741Z
    body: ''
  brxamt49:
    title: Cartelle, filtri e copia
    refs:
    - main-window
    - library
    - folder
    - requirements/ui#main-window
    - requirements/rules#main-window
    - requirements/data#folder
    - requirements/data#General
    - user.FILTER_BY_APP
    - user.SHOW_FOLDER
    - user.CREATE_FOLDER
    - user.RENAME_FOLDER
    - user.DELETE_FOLDER
    - user.MOVE_TO_FOLDER
    - user.COPY_SUMMARY
    - user.COPY_TRANSCRIPT
    technical: false
    proposal: 21la3pyo
    label: 'Redesign: archivio'
    finished: 2026-11-11T16:35:37.823Z
    body: |-
      Quando il lavoro è finito, la finestra principale offre le cartelle, i filtri per app, la ricerca di una parola nella trascrizione, le chip dei parlanti con la loro quota di tempo e la copia di sintesi e trascrizione, come descritti da `main-window`, `folder` e dai Requirements della libreria.

      ## Cartelle
      - L'archivio conserva un settimo tipo di record, la cartella: identificativo, nome e le call che contiene. Una call sta in al più una cartella, che non la possiede; eliminare una cartella lascia le sue call senza cartella. Un archivio salvato prima delle cartelle si apre senza cartelle e con ogni call senza cartella.
      - Nella barra laterale, dopo "Tutte le call" e "Segnalibri", l'eyebrow "Cartelle", le cartelle in ordine alfabetico e "+ Nuova cartella", che diventa un campo di testo sul fondo scuro: Invio crea (`user.CREATE_FOLDER`), Esc annulla. Il nome viene ripulito dagli spazi, è lungo al più 60 caratteri e deve essere diverso da quello di ogni altra cartella ignorando maiuscole e accenti; altrimenti non nasce nulla.
      - Dal menu contestuale di una cartella: rinomina (`user.RENAME_FOLDER`, con le stesse regole sul nome, altrimenti la cartella tiene il suo nome) ed elimina (`user.DELETE_FOLDER`: le call restano nell'archivio senza cartella; se la cartella mostrata è quella eliminata, la libreria torna su "Tutte le call").
      - `user.SHOW_FOLDER` mostra la vista cartella: titolo il nome della cartella, le stesse chip e card di "Tutte le call" ma solo per le sue call; senza call la pagina dice "Nessuna call in questa cartella". Ogni call resta comunque in "Tutte le call".
      - Nella pagina della call, "Sposta in cartella" (bottone outline con il nome della cartella attuale, quando c'è) apre un menu con le cartelle e "Nessuna cartella": scegliendo una cartella la call lascia la precedente ed entra in quella; "Nessuna cartella" la toglie dalla sua.

      ## Filtri per app
      - Sopra le card di "Tutte le call" e di una cartella, la riga dei filtri: "Tutte", poi una chip per ogni app di call a cui è legata almeno una call dell'archivio (o della cartella mostrata) in ordine alfabetico, poi "Manuali" se c'è una call registrata a mano e "Importate" se c'è una call importata; a destra il bottone testuale sottolineato "Importa file audio". Chip alte 32 px, la scelta in ink con testo lime.
      - `user.FILTER_BY_APP` mostra solo le call della chip scelta, "Tutte" mostra ogni call; la ricerca si applica sopra il filtro. Quando l'app della chip scelta non ha più call, il filtro torna su "Tutte". Ricerca e filtro restano quando si apre una call e si torna alla libreria.
      - Sulle card l'app è "Manuale" per una registrazione a mano e "Importata" per un file importato. Una call importata è ordinata per l'ora di ultima modifica del suo file (che è il suo inizio).
      - La card mostra la forma d'onda della call, quando ne ha una, in una striscia ink alta 44 px, raggio 10, 10 px di margine laterale: 44 barre colorate per parlante (larghezza flessibile, al più 4 px, 2 px di spazio), barre `#6B6E64` per una call senza righe; la striscia manca finché la forma d'onda non è calcolata. Il calcolo è di un'altra Task.

      ## Pagina della call
      - Una chip per parlante ("Io" solo quando ha righe, e ogni partecipante) con avatar, nome e quota del tempo di parola in JetBrains Mono 11 px: somma di fine meno inizio delle sue righe sul totale di tutti i parlanti, percentuale intera arrotondata al più vicino, chip ordinate per quota decrescente. Le iniziali sono la prima lettera del nome mostrato, o il numero per "Partecipante <numero>". Un clic sulla chip di un partecipante lo rinomina; il link sottolineato "Rinomina parlanti" mette in rinomina la prima chip di partecipante; il campo propone sotto di sé, come chip cliccabili filtrate dal testo, i nomi offerti. La rinomina resta possibile solo per una call pronta.
      - Nel pannello della trascrizione, il campo "Trova una parola" (`#F1F1EA`, raggio 16, alto 32 px, lente, conteggio "<n> di <m>" e frecce su e giù mentre c'è testo): il testo viene ripulito e cercato nel testo mostrato di ogni riga ignorando maiuscole, accenti e larghezza dei caratteri; le parole trovate hanno fondo lime e la riga trovata guardata un contorno ink di 2 px; la prima riga mostrata è la prima trovata dopo la riga in ascolto; le frecce girano dall'ultima alla prima e scorrono alla riga. La riga in ascolto resta al centro, tranne mentre si guarda una riga trovata.
      - `user.COPY_SUMMARY` ("Copia sintesi", in alto, solo quando la call ha una sintesi) e `user.COPY_TRANSCRIPT` ("Copia trascrizione", link sotto le righe, solo quando la call ha righe) mettono negli appunti la sintesi o la trascrizione con lo stesso testo dell'esportazione Markdown; "Copiata" sostituisce l'etichetta per due secondi; la scheda mostrata non cambia.
      - "Elimina tutte le registrazioni" non viene sviluppata.

      ## Code notes
      Commit: 58d947126f08b8c7e4128d08782a627080bde977
      - Libreria/pagina: `Sources/LARP/Archive/ArchiveView.swift`, `CallDetailView.swift` (`.id(call.id)`, lo stato si azzera per call), `CallRow.swift`, `TranscriptView.swift` (`TranscriptLineRow`, scroll al centro).
      - Ricerca: riusare `CallSearch.normalized` per "Trova una parola" e per i nomi di cartella (case/accenti).
      - Copia: riusare `TranscriptExport.markdown` e `SummaryContent.markdownParagraphs` (unica fonte di sintesi per vista, ricerca, export); non duplicare.
      - Dati: `Sources/LARP/Model/Call.swift`, `ArchiveStore.swift` `schema` (nessun VersionedSchema): i nuovi campi devono avere default perché i vecchi archivi si aprano (vedi `summaryStateRawValue`).
      - Nomi: `CallNaming.swift` `displayTitle`, `Participant.displayName`; rinomina in `CallLifecycle.renameParticipant`.
      - Colori dei parlanti: mappatura stabile da `Participant.number`, `.me` in ink.
      - I commenti citano gli eventi del Model (`` `user.MOVE_TO_FOLDER` ``); i test logici con swift-testing, fake in `Tests/LARPTests/CallLifecycleFakes.swift`. Nessuna infrastruttura di test UI: testare la logica (filtri, quote, ricerca, regole sui nomi).
  dh44kade:
    title: Import, forma d'onda, correzioni
    refs:
    - call
    - requirements/data#call
    - requirements/tech#call/Created
    - requirements/tech#call/Ready
    - user.IMPORT_AUDIO
    - user.EDIT_LINE
    technical: false
    proposal: 21la3pyo
    label: 'Redesign: archivio'
    finished: 2026-11-11T16:34:00.216Z
    body: |-
      Quando il lavoro è finito, una call può nascere dall'import di un file audio, ogni call pronta ha la sua forma d'onda colorata per voce e il testo delle righe di una call pronta si corregge a mano, come dice `call`.

      ## Import di un file audio
      - "Importa file audio" nella libreria apre il pannello di apertura di sistema per i file audio; il file scelto (`user.IMPORT_AUDIO`) viene letto (qualsiasi formato che il sistema sa leggere, per esempio m4a, mp3, wav, aiff, caf) e convertito, fuori dal thread principale, con lo stesso convertitore e la stessa scrittura delle tracce di una registrazione, nella traccia dell'audio di sistema della call. Il file importato non viene mai tenuto né modificato; la call non ha traccia del microfono.
      - La call nasce solo dopo che la conversione è riuscita. Se il file non si può leggere o convertire, un avviso "Impossibile importare il file" con il motivo lo dice e non nasce nessuna call.
      - La call importata prende come titolo il nome del file senza estensione, come inizio l'ora di ultima modifica del file, come durata la lunghezza del suo audio, nessuna app di call, la lingua di trascrizione scelta in quel momento, ed è segnata come importata (un archivio salvato prima apre ogni call come non importata). Va in Trascrizione se la sua lingua è pronta, altrimenti in Attesa della lingua.
      - Viene trascritta e separata come le altre; poiché non ha microfono, tutte le voci diventano partecipanti e nessuna è "Io".

      ## Forma d'onda
      - Una call conserva, opzionale, la sua forma d'onda: 44 barre ordinate, ciascuna un livello da 0 a 1 e un parlante (io, un numero di partecipante, altri o silenzio), assente finché non è calcolata.
      - Ogni barra è il picco di entrambe le tracce sulla sua parte della call, su una scala da −50 dBFS a 0 dBFS, e prende il parlante della riga che copre il centro del suo tempo ("Io" quando è una riga del microfono, silenzio altrimenti).
      - Viene calcolata una volta quando la call diventa pronta, e di nuovo dopo una separazione che viene rifatta. Le tracce si leggono a blocchi, mai intere, fuori dal thread principale, e il risultato si salva con la call sul thread principale.
      - All'avvio, le call pronte senza forma d'onda e con audio la ricevono in sottofondo, una alla volta, dalla più recente, dopo che ogni altro lavoro dell'avvio è partito.

      ## Correzione del testo
      - Solo quando la call è pronta, "Modifica testo" sotto le righe rende il testo di ogni riga modificabile in posto, come campo senza bordo con una sottolineatura `#E4E4DC`, finché il link, che diventa "Fine", non viene scelto.
      - `user.EDIT_LINE` vale solo per una riga di questa call e per un testo non vuoto una volta ripulito: la riga prende il nuovo testo e, quando conserva un originale di una rifinitura, anche il suo testo originale prende il nuovo testo, così una nuova rifinitura parte da lì e "Ripristina originale" riporta il testo corretto; parlante e parlante originale non cambiano, e una correzione da sola non fa mai contare la call come rifinita. Un testo vuoto lascia la riga com'era.

      ## Code notes
      Commit: 58d947126f08b8c7e4128d08782a627080bde977
      - Transizioni: `Sources/LARP/Call/CallStateMachine.swift` `CallStateMachine.target`, `CallEvent` (tabella pura, gli eventi portano i fatti di guardia); effetti in `CallLifecycle.swift` `apply(_:to:)`, `enter(_:call:)`.
      - Coda di trascrizione: `CallLifecycle+Transcription.swift` `scheduleTranscription`; `TranscriptionService.transcribeFile(at:speaker:language:)` riusabile per l'import.
      - Conversione e scrittura tracce: `Sources/LARP/Recording/TrackPipeline.swift`. Percorsi: `Sources/LARP/Model/AppPaths.swift`; file `Recordings/<id>/system.caf`, salvati relativi.
      - Separazione rifatta: `CallLifecycle+Separation.swift` `finishSeparation` (punto per ricalcolare la forma d'onda); rifatta, sostituisce i partecipanti.
      - Originali di rifinitura: `TranscriptLine.swift`, `CallLifecycle+Refinement.swift` `applyRefinement`, `restoreOriginals`, `Call.isRefined` (rifinita = una riga ha un testo originale).
      - Nuovi campi SwiftData con default (vedi `summaryStateRawValue`); `ArchiveStore.schema`.
      - Lavoro per call come `Task` in `running*[id]`; annullare non è mai un fallimento. Fake in `Tests/LARPTests/CallLifecycleFakes.swift`.
      - Pannello di modifica: `Sources/LARP/Archive/TranscriptView.swift`.
  gbudpd9t:
    title: Pagina sintesi e vista Azioni
    refs:
    - main-window
    - playback
    - library
    - settings
    - requirements/ui#main-window
    - requirements/ui#settings
    - requirements/rules#main-window
    - requirements/data#settings
    - user.SHOW_ACTIONS_VIEW
    - user.SELECT_DECISION
    technical: false
    proposal: m8gfdshl
    label: 'Redesign: sintesi e omp'
    finished: 2026-11-11T17:29:56.345Z
    body: |-
      La finestra principale mostra la nuova sintesi sulla pagina della call, ha la vista "Azioni" di tutte le call, i campi per domande e traduzione, e le Impostazioni hanno le nuove voci della sezione Sintesi; ricerca, card ed esportazione Markdown seguono la nuova sintesi.

      ## Cosa deve valere

      - **Barra laterale**: la voce "Azioni" sta fra "Tutte le call" e "Segnalibri", disegnata come loro, e apre la vista Azioni.
      - **Vista Azioni**: titolo "Azioni"; le azioni delle sintesi delle call che corrispondono alla ricerca, raggruppate per call dalla più recente; dentro una call prima le non fatte, poi le fatte barrate, ciascuna nell'ordine della sintesi con spunta, testo, responsabile con il nome attuale del partecipante e scadenza come detta. Una card bianca per call con eyebrow (giorno, ora, app) e titolo in Bricolage Grotesque 19 px, righe come sulla pagina della call, le fatte barrate in `#5A5D55` su `#F1F1EA`. Spuntare qui equivale a spuntare sulla pagina della call; un clic fuori dalla spunta (sulla call o su un'azione) apre la pagina della call sulla sintesi e ne carica l'audio. Senza azioni: "Nessuna azione".
      - **Sintesi sulla pagina della call**: lo stato e, quando c'è, la frase d'apertura in Inter 24 px medium con la parte chiave su sfondo lime `#D4F24A`; poi "Decisioni" numerate "01", "02" con a destra l'ora della riga in un chip JetBrains Mono che fa partire l'audio da lì; "Azioni" in card bianche con spunta quadrata da 18 px, testo (barrato quando fatta), avatar del responsabile con "<nome> · <scadenza>"; "Rimasto aperto"; "Concetti chiave"; "Altro" solo se non vuoto. "Sintetizza"/"Rigenera" come oggi; una sintesi scritta mentre la pagina è aperta compare senza cambiare pagina.
      - **Clic su una decisione**: solo se la call ha audio da riprodurre, la riproduzione parte dall'inizio della riga in cui la decisione è stata presa (da ferma, in pausa o in riproduzione).
      - **Testi**: titoli delle sezioni nella lingua dell'interfaccia: "Decisioni", "Azioni", "Rimasto aperto", "Concetti chiave", "Altro", lista vuota "Nessuno" / "Decisions", "Action items", "Left open", "Key concepts", "Other", "None"; gli elementi restano nella lingua della sintesi. Ogni "Partecipante <numero>" si sostituisce col nome dato, se non vuoto, o con "Participant <numero>" in inglese; la sintesi salvata non cambia mai. Una sintesi di prima mostra le prossime azioni come azioni senza scadenza e niente rimasto aperto.
      - **Card**: mostra la frase d'apertura della sintesi (vuota: lo stato della call) e, con azioni non fatte, la chip "1 azione"/"<n> azioni" ("1 action"/"<n> actions").
      - **Ricerca**: cerca anche nella sintesi come mostrata (frase d'apertura, titoli, elementi, responsabili, scadenze, testo libero, con i nomi attuali), qualunque sia lo stato della sintesi e anche a sintesi spente; la parola della lista vuota non si cerca.
      - **Domande**: in fondo alla colonna sinistra, sotto le schede, domande (13 px semibold) e risposte (15 px), l'ultima con "omp sta rispondendo…" mentre attende, una fallita con il link "Riprova"; poi il campo scuro "Chiedi qualcosa a questa call", alto 52 px, raggio 26, con il pulsante lime "Chiedi" disattivato mentre omp risponde. Si mostra solo con l'interruttore acceso.
      - **Traduzione**: nel pannello della trascrizione il link "Traduci" fra "Modifica testo" e "Copia trascrizione"; legge "Traduzione in corso…" mentre omp traduce e "Mostra originale" a traduzione mostrata, con l'eyebrow "TRADOTTO IN <LINGUA>" sotto il titolo del pannello; un fallimento mostra "Traduzione non riuscita" in `#B42A18` accanto al link. Una domanda o traduzione in corso si annulla uscendo dalla pagina della call.
      - **Markdown** (esportazione, "Copia sintesi"): la parte Sintesi ha la frase d'apertura come paragrafo con la parte chiave in `**grassetto**`, poi per sezione `### <titolo>` con `- <elemento>`, le decisioni come `- [<orologio>] <testo>`, le azioni come `- [x] <elemento>` o `- [ ] <elemento>` (elemento = testo, ` · <responsabile>`, ` · <scadenza>`), o la parola della lista vuota, o il testo libero; poi note, segnalibri e trascrizione come già definiti.
      - **Impostazioni, sezione Sintesi**: "Sintetizza quando la call finisce" con lo stato di omp sotto quando è acceso; "Lingua della sintesi" con "Come la call", "Italiano", "English" (salvata, default "Come la call"); "Domande e traduzioni con omp" con interruttore, spiegazione "Chiedi qualcosa a una call e traducine la trascrizione" e, da acceso, lo stato di omp sotto (salvato, spento di default).

      ## Code notes

      Commit: 58d947126f08b8c7e4128d08782a627080bde977

      - Pagina call: `Sources/LARP/Archive/CallDetailView.swift` (`.id(call.id)`, lo stato si azzera per call), `CallSummaryView.swift` (`CallSummaryView`, `SummarySectionView`), `TranscriptView.swift`, card `CallRow.swift`, finestra `ArchiveView.swift`.
      - `Sources/LARP/Archive/SummaryContent.swift` è l'unica fonte per vista, ricerca ed export (`Words`, `replacingParticipants`, `markdownParagraphs`, `searchableTexts`, `Titles` it/en alla riga 117): estenderlo, non duplicarlo. Ricerca `CallSearch.swift` (`normalized`, `fields`); export `TranscriptExport.swift` (`markdown(for:)`, `ArchiveFormat` per l'orologio), `MarkdownDocument.swift`.
      - Riproduzione da una riga: `Sources/LARP/Playback/PlaybackController.swift` `play(fromSentenceStart:)`, `seek`.
      - Impostazioni: `Sources/LARP/Settings/SettingsView.swift` (`assistantText`).
      - Nei commenti delle viste citare gli eventi del Model (`user.SHOW_ACTIONS_VIEW`, `user.SELECT_DECISION`). Il colore dei parlanti va mappato in modo stabile da `Participant.number`, `.me` inchiostro.
      - Niente test UI: si verifica a mano; testare solo la logica (SummaryContent, ricerca, export, tabelle): `SummaryContentTests`, `TranscriptExportTests`.
---
# Finestra principale, Archivio e linguaggio visivo

Strato visivo condiviso con font inclusi e catalogo di stringhe in italiano e inglese; barra laterale scura, griglia di card con ricerca, pagina della call a schede (sintesi, note, segnalibri), cartelle e filtri, import di file audio, forma d'onda e correzione delle righe, segnalibri e note come dati della call; rimosso il codice delle vecchie transizioni di selezione.
