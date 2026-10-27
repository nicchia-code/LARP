---
column: done
technical: false
refs:
  - call
  - transcription
  - user.REFINE_TRANSCRIPT
  - user.RESTORE_TRANSCRIPT
  - requirements/rules#call
  - requirements/rules#main-window
  - requirements/data#call
  - requirements/tech#call/Refining transcript
  - requirements/quality#General
  - requirements/ui#main-window
drift: null
proposal: 1v7l5br8
agent: false
created: 2026-10-27T13:00:57.176Z
finished: 2026-10-27T13:12:54.266Z
---
# Rifinitura nel ciclo della call

Quando il lavoro è finito, la macchina `call` ha la rifinitura del testo fatta con omp. Questa Task usa il client ACP per omp scritto per la macchina `transcript-refinement` (avvio di `omp acp` isolato, `session/new`, `session/prompt`, raccolta dei `session/update`, rifiuto dei permessi, terminazione del processo).

**Transizioni**
- Da **Separating participants**, `call.PARTICIPANTS_SEPARATED` porta a **Ready** quando la rifinitura è spenta e a **Refining transcript** quando è accesa. In entrambi i casi ogni riga "Others" va al suo partecipante, come oggi.
- **Refining transcript**: il testo si legge già com'è uscito da trascrizione e separazione. Si mandano a omp le righe originali, mai l'audio. Ogni rifinitura riparte dalle righe originali, mai da una rifinitura precedente.
  - `call.TRANSCRIPT_REFINED` → **Ready**: ogni riga prende il testo e il partecipante corretti, e il testo e chi parla originali di ogni riga restano conservati.
  - `call.REFINEMENT_FAILED` → **Awaiting refinement retry**: il testo resta com'era.
  - `user.TURN_OFF_REFINEMENT` → **Ready**: la rifinitura si ferma (il processo omp viene terminato subito) e il testo resta com'era.
  - `macos.APP_LAUNCHED` → **Refining transcript**: l'app era stata chiusa durante la rifinitura, che riparte.
  - `user.RENAME_CALL` resta nello stato e cambia il titolo.
  - `user.DELETE_CALL` → **Deleted**: ferma la rifinitura e cancella audio e testo.
- **Awaiting refinement retry**: il testo si legge com'è uscito da trascrizione e separazione. La rifinitura è fallita e si riproverà da sola.
  - `macos.NETWORK_AVAILABLE` e `macos.APP_LAUNCHED` → **Refining transcript**.
  - `user.REFINE_TRANSCRIPT` → **Refining transcript** subito.
  - `user.TURN_OFF_REFINEMENT` → **Ready** con il testo com'era.
  - `user.RENAME_CALL` resta nello stato e cambia il titolo.
  - `user.DELETE_CALL` → **Deleted**.
- **Ready**:
  - `user.REFINE_TRANSCRIPT` → **Refining transcript**, solo se la rifinitura è accesa. Vale anche per una call già rifinita e per le call registrate prima che la rifinitura esistesse.
  - `user.RESTORE_TRANSCRIPT` → **Ready**, solo se la call è stata rifinita: ogni riga riprende testo e chi parla originali, e la call si rifinisce di nuovo solo su richiesta.
- Durante Refining transcript e Awaiting refinement retry non si rinominano i partecipanti.

**Cosa si manda.** Per ogni riga della call, in ordine di inizio: un numero di riga, chi parla originale come "Io" o "Partecipante <numero>" (mai un nome dato dall'utente), inizio, fine e testo originale. Il formato è JSON con `number`, `speaker`, `start`, `end`, `text`, preceduto da istruzioni fisse. Non si mandano mai l'audio, il titolo, i nomi dati dall'utente, le date o l'app della call.

**Istruzioni a omp.** Correggere ogni parola riconosciuta male, in qualsiasi lingua (per esempio le parole inglesi dentro frasi italiane). Non riformulare, riassumere, tradurre o cambiare stile, e non unire, dividere, aggiungere o togliere righe. Una riga può passare da un partecipante a un altro della stessa call; una riga "Io" resta "Io" e nessuna riga diventa "Io". Rispondere solo con JSON: un oggetto per riga con `number`, `text`, `speaker`.

**Validità della risposta.** La risposta si applica solo se ha esattamente una correzione per ogni riga mandata, ciascuna con testo non vuoto e con un `speaker` ammesso per quella riga. Se non è valida non si applica niente e si ha `call.REFINEMENT_FAILED`. Una risposta valida si applica a tutte le righe in un solo salvataggio, conservando per ogni riga il testo e chi parla originali. Senza una risposta completa entro 10 minuti dall'avvio del processo, il processo viene terminato e si ha `call.REFINEMENT_FAILED`. Lo stesso vale se omp non si trova o non risponde.

**Dati.** Una riga di una call rifinita conserva anche testo e chi parla originali. Il ripristino li rimette come testo e chi parla e li cancella. Una call è rifinita quando le sue righe hanno un originale.

**Esecuzione.** La rifinitura gira fuori dal main actor e non blocca mai l'interfaccia né una registrazione.

**Archivio.**
- La lista mostra "Rifinitura testo…" per Refining transcript e "Testo da rifinire" per Awaiting refinement retry.
- Nella barra degli strumenti ci sono:
  - "Rifinisci testo", attiva solo con la rifinitura accesa e la call Pronta o in "Testo da rifinire";
  - "Ripristina originale", attiva solo su una call rifinita, anche con la rifinitura spenta.
- Ricerca ed esportazione Markdown usano il testo e chi parla che la call mostra in quel momento.

**Privacy.** L'audio non esce mai dal Mac. Del testo esce solo quello elencato sopra, e solo con la rifinitura accesa.
