---
status: approved
base:
  system.md: b95fc3a4c0888e1451f153b46f177469da35dacfa8ba11b0aef587cb7082a49a
  actors/user.md: 14b4ad524c93cbaa4c8ea5a20bace827b9d92bb1996135b2015af6325527f765
  actors/assistant.md: new
  transcription/feature.md: 546abf223466e4ee2f49311d649a788e4d6e41cdd6680532729ae032614f442a
  transcription/call.md: 460a28dfd384b5a3fe4dfa64c96094bc1b362286c3b48b8281f7eaf0634bd40e
  settings/feature.md: 8304c7a987e0cd16d3a51f8b13a99237a6d813cc6d80d1c3c53b29f98d5bee93
  settings/transcript-refinement.md: new
  requirements/quality/main.md: 45a258eb42cffeab6fbb722a69ac8ed813f96a55bcf8e874db874dde6490943a
  requirements/tech/stack.md: d5969d702dc3978a71af8c63fbf0946de3bdb71b0b86b27e7b3306d1a8b1a54b
  requirements/data/storage.md: 5c65ef297443751666168a7ba605909f9780d51fba032b6d85aa1249fe8b7251
  requirements/rules/behaviour.md: d00fae1d1fccd78bc15b20d3679295cc12a21f64e9ad1213908e69c7d5ba662c
  requirements/ui/screens.md: ba6703f3a9768a1475654de60987fe31670f40a18536c613136c38e6c626192f
  specs.yaml: 9cce479796aa7d581c525cf6c002848afefcce79fcc26e2b61f831f239ce8cac
delete: []
created: 2026-10-27T12:58:21.643Z
label: Rifinitura omp
---
# Rifinitura testo con omp

Il trascrittore di Apple lavora in una sola lingua per volta: le parole inglesi dentro frasi italiane ("sono in call") e altri errori di riconoscimento restano nel testo, e la separazione per voce a volte dà una riga al partecipante sbagliato. Questa Proposal aggiunge una rifinitura del testo fatta da omp, avviato come server ACP sul Mac, con il modello configurato in omp. Esce dal Mac solo il testo della trascrizione, mai l'audio.

## Decisioni
- Esce dal Mac solo il testo delle righe con chi parla e i tempi di inizio e fine; mai l'audio, il titolo, i nomi dati dall'utente, le date o l'app della call. Il requisito di privacy cambia di conseguenza.
- Rifinitura automatica per le nuove call e su richiesta dall'archivio ("Rifinisci testo"), anche per le call vecchie.
- Nuova fase "Rifinitura testo…" dopo la separazione delle voci e prima di Pronta; il testo grezzo si legge già.
- Se non riesce (omp assente, nessuna risposta in 10 minuti, risposta che non corrisponde riga per riga) la call va in "Testo da rifinire" e si riprova da sola al ritorno della rete e all'avvio dell'app, oppure a mano.
- Una risposta che non corrisponde riga per riga non viene applicata per niente.
- Il modello corregge ogni errore di riconoscimento, in ogni lingua, senza riformulare, riassumere o cambiare stile.
- Il modello può spostare una riga solo tra i partecipanti della stessa call; "Io" resta "Io" e nessuna riga diventa "Io".
- Ogni riga conserva testo e chi parla originali; "Ripristina originale" riporta entrambi, e la call si rifinisce di nuovo solo su richiesta.
- Ogni rifinitura riparte dal testo e da chi parla originali, anche quando la call era già rifinita.
- Interruttore "Rifinisci il testo con omp" nelle impostazioni, spento di default; spento, anche l'azione a mano è disattivata.
- Spegnendo l'interruttore, la rifinitura in corso si ferma e le call in rifinitura o in attesa diventano Pronte con il testo originale.
- Le impostazioni mostrano se omp è pronto: trovato nel PATH della shell di login e risponde all'avvio come server ACP; la verifica avviene all'avvio dell'app, all'accensione dell'interruttore e all'apertura delle impostazioni.
- omp è isolato: cartella di lavoro temporanea vuota, nessuno strumento, nessuna sessione salvata.
- omp usa il proprio modello predefinito; LARP non sceglie il modello.
- Esportazione e ricerca usano il testo che la call mostra in quel momento.
- Testi: "Rifinitura testo…", "Testo da rifinire", "Rifinisci testo", "Ripristina originale", "Rifinisci il testo con omp", "omp pronto", "omp non trovato".

## Assunzioni da verificare
- Durante la verifica di omp le impostazioni mostrano "Verifica in corso…", come per la lingua di trascrizione.
- Con l'interruttore spento "Rifinisci testo" è disattivata, non nascosta; "Ripristina originale" resta attiva su una call rifinita anche con l'interruttore spento, perché non manda niente fuori dal Mac.
- "Rifinisci testo" vale solo per call Pronte o in "Testo da rifinire"; durante la rifinitura, come durante la separazione, non si rinominano i partecipanti.
- Il protocollo ACP è parlato direttamente sull'input e output standard del processo, senza nuove dipendenze: FluidAudio resta l'unica dipendenza di terze parti.
- omp viene avviato per ogni verifica e per ogni rifinitura e chiuso alla fine; il disco non conserva niente di omp tra una rifinitura e l'altra.
- La verifica considera omp pronto se risponde a `initialize` entro 10 secondi.
- Le opzioni `--no-tools` e `--no-session` di `omp acp` si usano quando omp le accetta: la Task lo verifica; il rifiuto dei permessi e l'assenza di file system e terminale lato client valgono comunque.
- Il README viene aggiornato: niente più "no cloud" assoluto, e una spiegazione di cosa serve per la rifinitura.
