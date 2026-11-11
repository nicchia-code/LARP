---
status: approved
kind: change
base:
  model/actors/user.md: 37a6c6b7dd4c809689a9cdb38d795302a314d4a125f36b58ca3953f925201d9c
  model/capture/feature.md: 029e7947e1adcc7908850a2a11ccb7ee5d3cf5c9ce57a64acb71095be41ec5ce
  model/capture/recorder.md: d7a1d3d88082ce849765a9c4fcf7926e71b1fd5bc2c17d82039f5280c7093dec
  model/library/feature.md: 52f266911bfe1d2fdecafbbc1999d39ff5cc26d5316ec4be4fe856dd0e13a583
  model/library/main-window.md: a9f10b5580e9253a85912e0b8b548d8c14eafcc4f17c196e659613a98d45c580
  model/library/playback.md: ed37a8c91e19b5331aaa487a10de24b5f1ba00407c5cbcfb7a42e5c5e149ec89
  model/settings/feature.md: 2bb9b531078b8a51cfe1f55d745e7185a138399ff8dde757c2bb9da3fc00668a
  model/system.md: be1ab76e5e69da852bf88bbfa0762396a73e0080389b7c3bc4dd08a34d133cc0
  requirements/rules/capture.md: 04464ed23a616cc68f512ced05651df5736dcddea8e5e8bf2ba9570092048e8d
  requirements/rules/library.md: dfb68e970eb1cc31c0fde9e0b7b136f8823b2d20d41ef6d216fe496f7cded7f7
  requirements/rules/settings.md: b7f428a8079b354a9b31b3d7e4bcabb0bfd6e93508b826215572a4df81d65a67
  requirements/rules/transcription.md: ccca2e395b986eedd5099c23c9268f203925e7cc5629af558287e1d4d2bd4ae1
  requirements/tech/general.md: 37988aab9d89aa6831a4baed1675a54e0040d6413010b000d7941fd835e737f0
  requirements/ui/capture.md: new
  requirements/ui/general.md: new
  requirements/ui/library.md: new
  requirements/ui/settings.md: new
created: 2026-11-11T14:26:17.047Z
request: 2026-11-11T14-36-21
label: Redesign
job: oeg9sbc8
---
# Redesign: linguaggio visivo

Prima di sei Proposal del redesign secondo la Style Guide del designer: sostituisce l'aspetto dell'app con il nuovo linguaggio visivo e la nuova impaginazione, e rende l'interfaccia bilingue. Le funzioni nuove arrivano nelle Proposal che seguono.

## Decisioni

- Il linguaggio visivo della Style Guide si segue alla lettera e sostituisce del tutto l'aspetto attuale.
- Le schermate della Style Guide vengono allegate ai Task di interfaccia.
- Interfaccia in italiano o inglese secondo la lingua del sistema; inglese quando il sistema non è in nessuna delle due.
- Titoli predefiniti, "Io"/"Altri", titoli delle sezioni della sintesi ed esportazione Markdown si mostrano nella lingua attuale dell'interfaccia; i dati salvati non cambiano.
- Palette fissa come nel mockup, uguale anche con il Mac in modalità scura.
- Inter, Bricolage Grotesque e JetBrains Mono inclusi nell'app con la loro licenza SIL OFL.
- Icona della barra dei menu colorata come nel mockup; durante la registrazione resta il punto rosso con il tempo.
- Il clic sull'icona apre una finestra a comparsa scura al posto del menu, con "Esci" in fondo accanto a "Apri archivio" e "Impostazioni".
- La proposta di registrare resta nel pannellino che non prende il focus, ridisegnato come card scura; la stessa card compare nella finestra a comparsa e come banner in cima all'Archivio.
- Durante una registrazione la finestra a comparsa mostra la card della registrazione (le azioni di pausa e finestra dal vivo arrivano con la Proposal sulla registrazione).
- Archivio come griglia di card con una pagina per ogni call e "‹ Archivio"; nella pagina sintesi e trascrizione stanno affiancate, la riproduzione in basso.
- Senza sintesi la colonna sinistra mostra lo stato della sintesi e "Sintetizza" quando possibile.
- Azioni della pagina della call: in alto Esporta e un menu "…" con Rifinisci testo, Ripristina originale ed Elimina; "Rigenera" accanto alla sintesi; il titolo grande si rinomina con un clic.
- Le Impostazioni si aprono nella finestra principale, con "‹ Archivio" e le sezioni nella barra laterale; ⌘, le apre lì.
- Interruttori di omp nelle sezioni del mockup: rifinitura in Trascrizione, "Sintetizza quando la call finisce" in Sintesi, con lo stato di omp sotto ogni interruttore acceso.
- Trascrizione cloud non sviluppata: dove il mockup mostra la scelta compare solo la dicitura "Sul Mac: l'audio non lascia il computer".

## Assunzioni dell'agente

- La ricerca dell'Archivio resta com'è quando si apre una call e si torna indietro, come oggi nella vista divisa.
- Le call senza app di call mostrano "Manuale" al posto del nome dell'app nelle card.
- La card mostra il primo concetto chiave della sintesi finché la Proposal sulla sintesi non introduce la frase d'apertura.
- Misure, testi e formati non scritti nella Style Guide (dimensioni della finestra a comparsa e delle finestre, testi italiani tradotti dal mockup come "Tutto quello che è stato detto." e "Fallo tuo.", formati di data delle card, iniziali dei partecipanti senza nome come numero, colore grigio per "Altri") sono scelti dall'agente seguendo il mockup.

## Already present

- `user` — prose of the Actor only; its events are handled by the Machines of the Tasks
- `call/Ready/user.REFINE_TRANSCRIPT` — `Sources/LARP/Call/CallLifecycle+Refinement.swift` `refineTranscript`, `canRefine`
- `call/Awaiting refinement retry/user.REFINE_TRANSCRIPT` — `Sources/LARP/Call/CallLifecycle+Refinement.swift` `refineTranscript`
- `call/Ready/user.RESTORE_TRANSCRIPT` — `Sources/LARP/Call/CallLifecycle+Refinement.swift` `restoreTranscript`, `canRestore`
- `call-summary/No summary/user.SUMMARIZE_CALL` — `Sources/LARP/Call/CallLifecycle+Summary.swift` `summarize`, `canSummarize`
- `call-summary/Awaiting summary retry/user.SUMMARIZE_CALL` — `Sources/LARP/Call/CallLifecycle+Summary.swift` `summarize`
- `call-summary/Summarised/user.SUMMARIZE_CALL` — `Sources/LARP/Call/CallLifecycle+Summary.swift` `summarize`; `Sources/LARP/Call/CallSummaryStateMachine.swift`
