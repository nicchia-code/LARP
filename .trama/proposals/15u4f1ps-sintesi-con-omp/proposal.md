---
status: approved
base:
  system.md: 7913e8d70910d9fa257a24ff4de96472c3331accbaf1587e420817eb49830f0f
  settings/feature.md: 54815b851135cddd54d197e025176eb720fc816bacc15afb2e2bb8f4ff8f99b7
  settings/transcript-refinement.md: b74bbc8fce0ab4015c6aca66d4938180b5da04f7f1547f6d6082289c57e43a02
  settings/assistant-status.md: new
  settings/call-summaries.md: new
  transcription/feature.md: 60acc3db1ffe7fe6884a782626620610f880d6d8826f405825310364a13007a3
  transcription/call-summary.md: new
  library/feature.md: 4d9b3d1517f6c5585da90b742fb272f32468a209d103d1c4e356b75a1c9ff31d
  library/main-window.md: 15584ce021733546e27ba6feea25e6241e24ebe8fd6a3a66436baaaced7b1abf
  actors/user.md: b218857551180b028de43d434ad542347a3969424fae2efe0085d25f188b0d63
  actors/assistant.md: dabf281b00e476fe4ef31fc74b9bd7eeaff7881846bf600218b8ad4feaf03af0
  requirements/tech/stack.md: 2334cf274e36d3ace62c049edec13eef40c1d4d2ff2b36230b0cc075c12f80ef
  requirements/ui/screens.md: 3004f6f43c8fdf89caedeee9f9f8f63a318266b7b664b3c2fcc1837adbaaede9
  requirements/rules/behaviour.md: cbab49b1ff170f11aefa91c64e71bbca1adff3018be60eac1bc76d761ebeeb01
  requirements/data/storage.md: 6fefee07fb3a1ddb07e1832a49d937ee89017544724b2946671a24e44c870508
  requirements/quality/main.md: 5dacf8bc83e2062e24f67d197466d7446cd9ac6edb7a2b26f3279741201aa55f
  requirements/tech/assistant.md: new
delete: []
request: 2026-10-28T20-07-57
created: 2026-10-28T19:19:25.707Z
label: Sintesi
---
# Sintesi con omp

LARP serve soprattutto a ritrovare i concetti e le decisioni di una call, più che la trascrizione: oltre alla rifinitura, omp può scrivere, se l'utente lo vuole, una sintesi di quanto detto.


## Decisioni

- Interruttore proprio «Sintesi con omp» nelle Impostazioni, indipendente da «Rifinisci il testo con omp», spento di default.
- La sintesi parte da sola subito dopo la separazione delle voci e usa sempre il testo originale (non quello rifinito); rifinire o ripristinare il testo non cambia la sintesi.
- Le istruzioni a omp dicono che il testo viene da una trascrizione automatica e dalla separazione automatica delle voci, quindi può contenere parole e parlanti sbagliati; nell'app non compare alcuna nota.
- Con rifinitura e sintesi accese, le due partono in parallelo, ciascuna con il proprio processo omp; l'errore dell'una non ferma l'altra.
- Contenuto: elenchi fissi di concetti chiave, decisioni e prossimi passi, più un testo libero per ciò che non rientra negli elenchi.
- I prossimi passi indicano chi li deve fare («Io» o «Partecipante N») solo quando dalla call è chiaro.
- La sintesi è scritta nella lingua di trascrizione della call; anche i titoli delle sezioni seguono quella lingua.
- A omp si mandano solo «Io» / «Partecipante N», come per la rifinitura: mai nomi, titolo, date, app o audio.
- Nell'app, nella ricerca e nell'esportazione la sintesi mostra i nomi attuali dei partecipanti al posto di «Partecipante N».
- Stato proprio della sintesi: nella lista una call Pronta mostra «Sintesi…» o «Sintesi da fare».
- Se omp fallisce: nuovo tentativo da solo (rete, riavvio dell'app) o su richiesta, limite di 10 minuti, come la rifinitura.
- Pulsante «Sintetizza» per chiedere o rifare la sintesi di qualunque call con le voci già separate, anche registrata prima; la nuova sintesi sostituisce la precedente.
- Spegnendo la sintesi, quelle già scritte restano visibili, ricercabili ed esportabili; quelle in corso o da riprovare si fermano.
- Nella call selezionata un selettore «Sintesi» / «Trascrizione»; la scheda «Sintesi» c'è sempre, con un messaggio quando la sintesi manca o è in corso.
- L'esportazione Markdown mette «## Sintesi» prima di «## Trascrizione»; senza sintesi il file resta com'è oggi.
- La ricerca guarda anche nel testo della sintesi.
- La sintesi non si modifica a mano: si può solo rifare.
- Una call senza righe di trascrizione non riceve sintesi e il pulsante è disattivato.

## Assunzioni

- Il controllo di omp («Verifica in corso…», «omp pronto», «omp non trovato») esce da `transcript-refinement` e diventa la Machine `assistant-status`, attiva quando almeno una tra rifinitura e sintesi è accesa; lo stato è mostrato una volta sotto i due interruttori.
- La sintesi di una call è una Machine propria, `call-summary`, accanto a `call`, perché corre in parallelo alla rifinitura.
- Mentre si rifà una sintesi, o se il nuovo tentativo fallisce, la sintesi precedente resta visibile finché la nuova non la sostituisce.
- Una sezione vuota mostra «Nessuno» («None» in inglese); «Altro» non compare se il testo libero è vuoto.
- omp risponde con un unico oggetto JSON (concetti, decisioni, prossimi passi con responsabile facoltativo, testo libero); una risposta non valida non salva nulla e la sintesi fallisce.
- Le sezioni dei Requirements tecnici su omp passano nel nuovo fragment `tech/assistant`, perché `tech/stack` avrebbe superato i 12 KB.

## Already present
- `library` — Sources/LARP/Archive/ArchiveView.swift : `ArchiveView` (descrizione della Feature aggiornata; il codice è nei Task della finestra archivio)
- `settings` — Sources/LARP/Settings/SettingsView.swift : `SettingsView` (descrizione della Feature aggiornata; il codice è nei Task delle Impostazioni)
- `transcription` — Sources/LARP/Call/CallLifecycle.swift : `CallLifecycle` (descrizione della Feature aggiornata; il codice è nel Task della sintesi)
- `assistant` — Sources/LARP/Assistant/ACPClient.swift : `ACPClient` (descrizione dell'Actor aggiornata; la stessa connessione serve alla sintesi)
- `requirements/tech#call/Refining transcript` — Sources/LARP/Assistant/TranscriptRefiner.swift : `OmpTranscriptRefiner.refine`; Sources/LARP/Call/CallLifecycle+Refinement.swift : `startRefinement` (sezione solo spostata nel fragment `tech/assistant`)
- `requirements/tech` — Sources/LARP/Assistant/OmpLocator.swift : `LoginShellOmpLocator`; Sources/LARP/Assistant/Omp.swift : `Omp.open` (la sezione `transcript-refinement` è solo spostata in `assistant-status`)
