---
status: approved
kind: change
requires:
- skvedwa5
base:
  model/actors/user.md: 3507365f1d702b3491dbcc72060def0dd39e933137ef5183edc08ba3617be5e0
  model/capture/feature.md: 6427f8f5624293d2a0b0287b8e84cae071e6c1ae9770f452256c2724e162b431
  model/capture/microphone.md: 40bb16db2d71a307850bbd4a43c998265c8229daa51911d337846b36ea86aff8
  model/capture/recorder.md: 37659aea0e8bd15474151584219fe993c206ef2ddd5f62a77747ffa586f36f22
  model/capture/recording-view.md: new
  model/library/main-window.md: 746e7e8cc13fb68f67b8ae0ff7e2b65e02dfd925c4d9c703ea4bb9a445fe7266
  model/library/playback.md: da0de4db620d7ed2b261028de036629ef02502690a60953e9e628270268e191f
  model/settings/auto-recording.md: new
  model/settings/call-detection.md: new
  model/settings/feature.md: 68c8a21a638f3ca825ecab1c8e44b95dc3ead9e361f0eadca43a88b582d37d83
  model/settings/microphone-choice.md: new
  model/settings/onboarding.md: new
  model/settings/shortcuts.md: new
  model/system.md: 8747a9dbf40f5c1bdb36e45561d71c7e983d5b03d6ae8de46ec5e97a876867e4
  model/transcription/bookmark.md: new
  model/transcription/call.md: bdfec169524e92047f1449b6c41b3b7d459712114d657926d11bfe9c1c166194
  model/transcription/feature.md: 1488dc180b79ea836b3387f8849258862c789dde8550dee52293149ab086f3dd
  model/transcription/note.md: new
  requirements/data/capture.md: 6024dce251030c38f305960e55a14532a72a8fd12d8433dec74d64dfdeecc701
  requirements/data/general.md: f5cc7a21078c90a4ae7c8a06e99531f18c8704ef093adc5acf39c36373c4180a
  requirements/data/settings.md: c49e934bbfd12916f433fb7fa188b4477014164399e03728c2a4ab82fd4a9ad5
  requirements/data/transcription.md: a09434b3ab223ac92a01f3db2f0d99befbbf7ea430d3be1273d81070c382cd27
  requirements/rules/capture.md: 8f2e45a4876ba8b22ae9a954b348191075be7b707ea7ee612a9f109cf9596fe1
  requirements/tech/capture.md: d43cc9a51b8ee629be1fd816aeb0365dcc8506619f4392d109619ee65e96ad95
  requirements/ui/capture.md: 94b72acae5c7c7cdcdc3843c64ae1c6fa90949aa128bedc43afadf3d159870b5
  requirements/ui/library.md: c9b33ddd5ecafa62cb9b4796ffa7350b56ac816a150f9ee58eaf98992d6b3c33
  requirements/ui/settings.md: b50f42ded97567cda5a9c484053b013752c08fdac4a9efd2a3c8b0b09838717a
  specs.yaml: a77a86ad9a5866021f94962cee9dc62afd215a44ff72ba8c6bc7e50f907c3e72
created: 2026-11-11T14:32:19.272Z
label: 'Redesign: registrazione'
job: oeg9sbc8
---
# Registrazione arricchita

Seconda Proposal del redesign: aggiunge le funzioni della Style Guide intorno alla registrazione, sopra il nuovo linguaggio visivo.

## Decisioni

- Schermata di benvenuto al primo avvio, in due passi: permessi (microfono, audio di sistema), poi lingua di trascrizione con lo stato del modello e gli interruttori di rifinitura e sintesi con lo stato di omp; non ricompare.
- "Non questa" scarta la proposta finché quell'app non smette di usare il microfono; se poi l'utente sceglie "Registra" mentre l'app usa ancora il microfono, la registrazione è legata all'app come accettando la proposta.
- Pillola flottante durante la registrazione (punto rosso, tempo, forma d'onda dal vivo, segnalibro, pausa, stop); si nasconde mentre la finestra dal vivo è aperta.
- Finestra di registrazione dal vivo, aperta solo a richiesta dalla pillola o dalla finestra a comparsa: trascrizione dal vivo con "Io" e "Altri" e la frase in corso in grande, livelli Call e Mic, riquadro "Nella call" con chi parla, lingua scelta, note.
- Pausa che scrive silenzio in entrambe le tracce: i tempi della call restano quelli dell'orologio.
- Segnalibri durante la registrazione e durante l'ascolto, eliminabili, nella trascrizione, nella scheda "Segnalibri" della call e in una vista "Segnalibri" di tutte le call; un clic riproduce da lì.
- Note con l'ora, scritte durante la call o dopo nella scheda "Le mie note" (con l'ora dell'ascolto, o senza ora), modificabili ed eliminabili; non vanno a omp.
- Scorciatoie globali modificabili e cancellabili: ⌥⌘R avvia o ferma, ⌥⌘B aggiunge un segnalibro; una combinazione già usata dall'altra viene rifiutata.
- "Registra automaticamente le call rilevate", spento di default: con i permessi già concessi parte senza proposta, altrimenti compare la proposta.
- Interruttore "Rileva le call" e un chip per ogni app nota da sorvegliare; spegnendo il rilevamento la proposta mostrata sparisce. L'obiettivo principale è Microsoft Teams.
- Scelta del microfono nelle Impostazioni e nella finestra a comparsa, "Predefinito di sistema" di default; se il microfono scelto non c'è si usa il predefinito; una scelta durante la registrazione cambia subito microfono.
- Non sviluppati: promemoria del consenso, "Ferma e sintetizza" (resta "Ferma").

## Assunzioni dell'agente

- Smettere di sorvegliare l'app della proposta mostrata fa sparire la proposta, come spegnere il rilevamento.
- Chiudere la schermata di benvenuto vale come completarla.
- Il microfono scelto torna in uso da solo quando viene ricollegato.
- Tornando da una call, l'Archivio riprende la vista da cui era stata aperta.
- Soglie dei livelli dal vivo scelte dall'agente: picco ogni 50 ms, 20 aggiornamenti al secondo, scala da −60 a 0 dBFS; una traccia "parla" sopra −40 dBFS per almeno 200 ms.
- Un segnalibro allo stesso secondo di un altro della stessa call non viene creato di nuovo.
- L'avviso della perdita del microfono passa dal registratore alla Machine del microfono, senza cambiare ciò che vede l'utente.

## Already present

- `user` — prose of the Actor only; its events are handled by the Machines of the Tasks
- `call-summary/Kept/call.DELETED` — `Sources/LARP/Call/CallLifecycle.swift` `delete(_:)`; `Sources/LARP/Model/ArchiveStore.swift` `delete`
- `call-summary/Summarising/user.TURN_OFF_SUMMARY` — `Sources/LARP/Call/CallLifecycle+Summary.swift`; `Sources/LARP/Settings/CallSummariesController.swift` turn-off stream
- `call-summary/Awaiting summary retry/user.TURN_OFF_SUMMARY` — `Sources/LARP/Call/CallLifecycle+Summary.swift`; `Sources/LARP/Call/CallSummaryStateMachine.swift`
- `call-summary/Awaiting summary retry/user.SUMMARIZE_CALL` — `Sources/LARP/Call/CallLifecycle+Summary.swift` `summarize`
- `call-summary/No summary/user.SUMMARIZE_CALL` — `Sources/LARP/Call/CallLifecycle+Summary.swift` `summarize`, `canSummarize`
- `call-summary/Summarised/user.SUMMARIZE_CALL` — `Sources/LARP/Call/CallLifecycle+Summary.swift` `summarize`
