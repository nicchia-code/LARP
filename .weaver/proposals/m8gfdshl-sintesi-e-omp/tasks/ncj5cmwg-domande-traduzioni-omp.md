---
refs:
- call-question
- transcript-translation
- call-questions
- assistant-status
- assistant
- requirements/rules#call-question
- requirements/rules#transcript-translation
- requirements/rules#assistant-status
- user.ASK_CALL
- user.TRANSLATE_TRANSCRIPT
- user.SHOW_ORIGINAL
- user.TURN_ON_QUESTIONS
- user.TURN_OFF_QUESTIONS
---
# Domande e traduzioni omp

Due nuove funzioni con omp sulla call mostrata: le domande ("Chiedi qualcosa a questa call") e la traduzione della trascrizione ("Traduci"), comandate da un nuovo interruttore "Domande e traduzioni con omp".

## Cosa deve valere

- **Interruttore**: salvato, spento di default (resta acceso se lasciato acceso). Da spento, "Chiedi qualcosa a questa call" e "Traduci" non si mostrano. Accenderlo salva la scelta e fa cercare omp se non lo si cercava già; spegnerlo salva la scelta e ferma una domanda o una traduzione in corso. Funziona che omp sia raggiungibile o no.
- **Stato di omp**: omp si cerca solo mentre almeno uno fra rifinitura, sintesi e domande e traduzioni è acceso; il Non necessario/Necessario tiene conto di tutti e tre gli interruttori (si spegne solo quando gli altri due sono spenti, abbandonando il controllo in corso e ignorandone il risultato). Con un interruttore lasciato acceso l'app parte in Controllo, ma cerca omp solo dopo l'avvio; aprire le impostazioni ricontrolla; vale solo l'ultimo controllo. Pronto e Mancante restano tali quando si accende un altro interruttore. Ricerca, avvio e risposta di 10 secondi come oggi.
- omp, l'assistente, ora risponde anche con la risposta a una domanda sulla call o con una traduzione della trascrizione.
- **Domande**: il campo è disponibile solo con l'interruttore acceso e una call con righe. Una domanda non vuota una volta rifilata va alla lista con una riga che dice che omp sta rispondendo, e il campo attende (non ne accetta altre). omp riceve, in un processo proprio, le righe come si vedono (testo rifinito o corretto incluso), ordinate per inizio e poi fine, numerate da 1, come array JSON con `number`, `speaker` ("Io" o "Partecipante <numero>", mai un nome dato dall'utente), `start`, `end`, `text`, poi la domanda rifilata; mai audio, titolo, nomi dati, informazioni della riunione, note, date o app; le domande precedenti non si rimandano. Istruzioni in italiano: rispondere solo dalle righe, nella lingua della domanda, nominando le persone solo "Io" e "Partecipante <numero>", e dire che la call non lo dice quando le righe non lo dicono; risposta in testo semplice. La risposta è tutto il testo, rifilato; vuota è un fallimento.
- Risposta valida: compare sotto la sua domanda con i nomi attuali dei partecipanti al posto di "Partecipante <numero>". Fallimento (omp non trovato, termina, errore, risposta vuota o incompleta entro il limite): la domanda mostra che omp non ha potuto rispondere, con "Riprova" che la richiede. Mai fallimento quando è stata fermata.
- Domande e risposte si accumulano in ordine finché la pagina della call resta aperta e non si salvano mai: tornare all'archivio, aprire le impostazioni, chiudere la finestra o eliminare la call mostrata svuota la lista e chiude subito un processo in corso. Spegnere l'interruttore durante una risposta chiude il processo e la domanda mostra che è stata fermata.
- **Traduzione**: "Traduci" è disponibile solo con l'interruttore acceso e la call pronta. Traduce nell'altra lingua (inglese per una call in italiano, italiano per una call in inglese), in un processo proprio, con le righe inviate come per una domanda seguite dalla lingua di destinazione. Istruzioni in italiano: tradurre il testo di ogni riga senza unire, dividere, aggiungere o togliere righe né cambiare parlanti; risposta solo come array JSON con `number` e `text`. Controllo: il testo dal primo `[` all'ultimo `]` deve decodificarsi in quell'array, con tanti elementi quante le righe inviate, ogni numero una volta e ogni testo non vuoto; altrimenti fallisce.
- Durante la traduzione il link dice che è in corso; a traduzione riuscita ogni riga mostra la traduzione al posto del suo testo e il link diventa "Mostra originale", che la scarta. Orari, parlanti, segnalibri e la riga in ascolto restano com'erano. Fallimento: torna l'originale e il pannello dice che non è riuscita. La traduzione non si salva mai.
- In corso, la traduzione si ferma subito (processo chiuso, torna l'originale) tornando all'archivio, aprendo le impostazioni, chiudendo la finestra, spegnendo l'interruttore, correggendo una riga o eliminando la call mostrata. Tradotta, si scarta con gli stessi gesti di navigazione, con una rifinitura arrivata per la call mostrata o con la correzione di una riga, che prende il testo battuto sopra il suo testo originale.
- Domande e traduzioni usano la stessa ricerca di omp, lo stesso avvio (`omp acp --no-tools --no-session`, poi `omp acp` se termina subito, cartella temporanea vuota), lo stesso limite di 600 secondi di tutte le richieste e la stessa gestione dei permessi.

## Code notes

Commit: 58d947126f08b8c7e4128d08782a627080bde977

- Processo omp: `Sources/LARP/Assistant/TranscriptRefiner.swift` `TranscriptRefining.refine(prompt:)`, `OmpTranscriptRefiner.timeLimit`: riusarlo per le nuove richieste invece di duplicarlo.
- Righe per omp: `Sources/LARP/Refinement/RefinementRequest.swift` `RefinementLine.originalLines/json`, `RefinementSpeaker`; qui servono le righe come mostrate, non le originali. Ordinamento `Call.sortedLines` in `Sources/LARP/Archive/TranscriptExport.swift`. Le risposte si leggono estraendo il `[…]` più esterno.
- Stato di omp: `Sources/LARP/Settings/AssistantStatusController.swift` (`openSettings()`, `appLaunched()`, controllo via `OmpAssistantCheck` in `Sources/LARP/Assistant/`); "vale l'ultimo" si fa con un intero `generation`.
- Interruttore: chiave `settings.callQuestions` in `Sources/LARP/Settings/SettingsKey.swift`; modello `CallSummariesController.swift`, `TranscriptRefinementController.swift` (`turnOffEvents`); flussi con `EventBroadcaster<T>`; cablaggio in `Sources/LARP/App/LARPApp.swift` `init()`.
- Nomi: `Sources/LARP/Call/CallNaming.swift` `speakerName`, `Participant.displayName`.
- Il lavoro gira come `Task` con token; annullare non è mai un fallimento. `CallDetailView` è keyed su `.id(call.id)`, quindi lo stato per pagina si azzera da sé cambiando call. Ogni Machine è una classe `@MainActor` con tabella di transizioni pura e dipendenze dietro protocolli (fake nei test, `.serialized`).
