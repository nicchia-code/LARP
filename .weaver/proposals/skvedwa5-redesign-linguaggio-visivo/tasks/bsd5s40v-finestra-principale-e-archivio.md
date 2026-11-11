---
refs:
  - main-window
  - library
  - requirements/ui#main-window
  - requirements/rules#main-window
  - user.OPEN_WINDOW
  - user.CLOSE_WINDOW
  - user.SELECT_CALL
  - user.DESELECT_CALL
  - user.ASK_TO_DELETE
  - user.EXPORT_CALL
  - user.REFINE_TRANSCRIPT
  - user.RESTORE_TRANSCRIPT
  - user.SUMMARIZE_CALL
  - user.CLOSE_SETTINGS
---
# Finestra principale e Archivio

La finestra dell'archivio diventa la finestra principale: barra laterale scura e una pagina alla volta (Archivio, pagina di una call, Impostazioni). Le schermate della Style Guide (04 Library e 05 Meeting) sono allegate a questo Task.

## Cosa deve valere alla fine

- Finestra di circa 1200 × 920 px all'apertura, almeno 900 × 600, senza barra del titolo visibile né toolbar: i pulsanti della finestra stanno sulla barra laterale. `user.OPEN_WINDOW` porta l'app in primo piano e mostra l'Archivio; `user.CLOSE_WINDOW` ferma la riproduzione.
- Barra laterale ink 210 px: marchio LARP con "LARP", "Nuova registrazione" (lime, disabilitata al 40 % mentre qualcosa è proposto o registrato; avvia una registrazione a mano come "Registra" nella finestra a comparsa, senza cambiare pagina), "Tutte le call" e in fondo "Impostazioni"; l'elemento scelto è `#23251F` con testo lime.
- Archivio, una griglia di card: eyebrow "<giorno breve> <giorno> <mese breve> · <n> call oggi" (nessuna: "nessuna call oggi" / "no calls today"; si contano le call iniziate oggi nel calendario del Mac), titolo "Tutto quello che è stato detto." e campo di ricerca "Cerca parole, persone, decisioni". La ricerca resta quando si apre una call e si torna indietro. Mentre c'è una proposta, sopra le card c'è il banner ink "In onda ora · <app di call>", "Call rilevata" e "Registra questa call", che accetta la proposta.
- Una card per call che corrisponde alla ricerca, la più recente prima, colonne di almeno 280 px: giorno e ora (`Oggi 10:00`, giorno breve negli ultimi sette giorni, altrimenti `27 ott 10:41`), app di call ("Manuale" per una registrazione a mano), titolo (due righe al massimo), il primo concetto chiave della sintesi oppure lo stato, gli avatar dei partecipanti con "Io" (iniziale del nome, o il numero per "Partecipante <n>"), la durata (`<n> min`, `<h> h <m> min`; non durante la registrazione) e il chip di stato, lime a trascrizione completa, `#ECECE4` mentre è in lavorazione. Archivio vuoto: "Nessuna registrazione"; nessuna corrispondenza: un testo che dice che non si è trovato nulla.
- Ricerca, sintesi mostrata, ordine delle righe, esportazione Markdown, nome predefinito del file e formati restano come nella Requirement delle regole, nella lingua dell'interfaccia.
- `user.SELECT_CALL` apre la pagina della call e ne carica l'audio; "‹ Archivio" (`user.DESELECT_CALL`) torna all'Archivio e scarica l'audio. In alto a destra "Esporta" e un menu "…" con "Rifinisci testo", "Ripristina originale" ed "Elimina", ciascuno abilitato solo quando la call lo permette; rifinitura e ripristino sono passati alla call senza cambiare pagina. `user.EXPORT_CALL` solo se la call ha righe: pannello di salvataggio di sistema con il nome predefinito, esito non riportato. `user.ASK_TO_DELETE` solo se la call non è in registrazione: dialogo "Eliminare la call?"; confermando la call si elimina con audio, trascrizione, partecipanti e sintesi e si torna all'Archivio. Anche una call eliminata altrove mentre è mostrata riporta all'Archivio.
- Sotto: eyebrow "<app di call> · <giorno e ora> · <durata>", il titolo grande 56 px, che si rinomina con un clic (salvato a conferma o perdita del focus, solo se cambiato; non durante la registrazione), lo stato della call e i chip dei partecipanti, dove il clic sul nome lo rinomina.
- Due colonne, circa 55 % e 45 %: a sinistra "Sintesi" con le sue sezioni in sola lettura (decisioni numerate "01", "02"); senza sintesi la colonna mostra lo stato della sintesi e "Sintetizza" quando possibile, con la sintesi "Rigenera" accanto; entrambi passati alla sintesi della call (`user.SUMMARIZE_CALL`). Una sintesi scritta mentre la pagina è mostrata compare al suo posto. A destra la card "Trascrizione": righe in ordine con il punto del colore del parlante, eyebrow "<PARLANTE> <ora>" e testo; la riga ascoltata ha sfondo `#EEF8B4` ed è tenuta al centro; durante la registrazione le righe compaiono man mano. Senza righe: "Nessuna trascrizione" per una call finita, altrimenti che la trascrizione non è ancora disponibile. In basso, la barra di riproduzione, tranne durante la registrazione.
- Le Impostazioni si mostrano nella stessa finestra; `user.CLOSE_SETTINGS` ("‹ Archivio") torna all'Archivio.

## Code notes
Commit: 58d947126f08b8c7e4128d08782a627080bde977
- `Sources/LARP/App/LARPApp.swift` `Window("Archivio", id: "archive")`, `archiveWindowID`, ambiente `CallLifecycle`; `NSApp.activate()` prima di `openWindow` (LSUIElement).
- `Sources/LARP/Archive/ArchiveView.swift` `ArchiveView` (`NavigationSplitView`, `toolbar`, `searchable`, `fileExporter`, dialogo di eliminazione, `.callDeleted`) da sostituire.
- `CallDetailView.swift` (titolo, rinomina, `show()`/`updateTimeline()`, `.id(call.id)` azzera lo stato per call), `CallRow.swift`, `TranscriptView.swift` (`TranscriptLineRow`, scroll al centro, clic per saltare), `CallSummaryView.swift`.
- `SummaryContent.swift`: fonte unica di sintesi in vista, ricerca, export; estenderla, non duplicarla. `CallSearch.swift`, `TranscriptExport.swift` (`defaultFileName`, `Call.sortedLines`).
- `CallLifecycle.swift` `canRename`, `canDelete`, `renameCall`, `renameParticipant`, `deleteCall`; `+Refinement` `canRefine`, `canRestore`; `+Summary` `canSummarize`, `summarize`.
- Riferimenti agli eventi del Model nei commenti; niente test UI, solo logica (formati, ricerca).
