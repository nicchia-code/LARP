---
created: 2026-11-11T16:47:20.730Z
updated: 2026-11-11T16:47:20.730Z
summary: Nuova struttura della sintesi e domande e traduzioni con omp sulla pagina della call.
tasks:
- n84527o1
- ncj5cmwg
cleared:
  n84527o1:
    title: Nuova struttura della sintesi
    refs:
    - call-summary
    - summary-language
    - requirements/data#call-summary
    - requirements/rules#call-summary
    - user.CHOOSE_SUMMARY_LANGUAGE
    - user.TOGGLE_ACTION_ITEM
    technical: false
    proposal: m8gfdshl
    label: 'Redesign: sintesi e omp'
    finished: 2026-11-11T16:31:45.566Z
    body: |-
      La sintesi di una call passa alla struttura della Style Guide: frase d'apertura con la sua parte chiave, concetti chiave, decisioni con la riga in cui sono state prese, azioni con responsabile e scadenza come dette nella call, ciò che è rimasto aperto e il testo libero per ciò che non rientra altrove. Le "prossime azioni" attuali diventano azioni.

      ## Cosa deve valere

      - **Dati salvati**: la sintesi conserva frase d'apertura (vuota per le sintesi scritte prima), parte evidenziata (può essere vuota), concetti chiave, decisioni (testo e, facoltativo, l'inizio in secondi della riga che omp ha indicato), azioni (testo, responsabile facoltativo, scadenza facoltativa "come detta", stato fatta/non fatta, non fatta di default), rimasto aperto, testo libero, lingua chiesta e ora di scrittura. Una call ne ha al più una.
      - Un archivio salvato prima di questa versione si apre: le prossime azioni diventano azioni senza scadenza e non fatte, le decisioni restano senza riga, niente frase d'apertura e niente rimasto aperto.
      - Il responsabile si salva esattamente come l'ha scritto omp, "Io" o "Partecipante <numero>"; i nomi dati dall'utente non vi finiscono mai, si sostituiscono solo quando si mostra.
      - **Lingua della sintesi**: nuova scelta salvata "Come la call" (default; un valore sconosciuto vale come "Come la call"), "Italiano" o "English". "Come la call" chiede la sintesi in inglese se la call è in inglese, altrimenti in italiano; le altre due scelte valgono qualunque sia la lingua della call. La lingua chiesta si salva con la sintesi; una nuova scelta vale per le sintesi scritte dopo, quelle già scritte tengono la loro lingua.
      - **Cosa riceve omp**: invariato: solo le righe originali (anche dopo una rifinitura), mai audio, titolo, nomi dati dall'utente, note, date o app; una riga degli altri senza partecipante fa fallire la sintesi senza inviare nulla.
      - **Istruzioni** (in italiano, con la lingua chiesta): le righe vengono da riconoscimento e separazione automatici e possono contenere parole e partecipanti sbagliati, da interpretare senza segnalarlo; persone nominate solo "Io" e "Partecipante <numero>", mai nomi indovinati; una frase d'apertura di al più 40 parole che dica l'esito della call, con la parte chiave (poche parole consecutive) data anche a parte; i concetti chiave; le decisioni con il numero della riga; le azioni, con il responsabile solo quando la conversazione lo rende chiaro e la scadenza solo quando è detta, scritta come detta (per esempio "venerdì"), mai una data calcolata (omp non riceve mai la data); ciò che è rimasto aperto; il testo libero. Ogni lista e il testo possono essere vuoti. Risposta solo come oggetto JSON con `opening`, `openingHighlight`, `keyConcepts`, `decisions` (`text`, `line`), `actionItems` (`text`, `owner` e `due` facoltativi), `openQuestions`, `other`.
      - **Controllo della risposta**: il testo dal primo `{` all'ultimo `}` deve decodificarsi con tutti e sette i campi. Un responsabile diverso da "Io" o "Partecipante <n>" con n un partecipante della call, scritto esattamente così, rende invalida tutta la risposta. Una `line` che non è il numero di una riga inviata lascia la decisione senza riga (nessuna ora mostrata). `openingHighlight` si tiene solo se compare così com'è dentro `opening`, ignorando maiuscole; altrimenti nulla è evidenziato. Ogni testo si rifila; elementi vuoti, decisioni e azioni con testo vuoto si scartano, una scadenza vuota vale come assente; una frase d'apertura vuota è ammessa.
      - **Spunta delle azioni**: spuntare un'azione della sintesi di una call la segna fatta, o di nuovo non fatta, e la scelta si salva; lo stato della sintesi non cambia. Quando una nuova sintesi sostituisce quella precedente (anche con "Rigenera") ogni azione riparte non fatta: le spunte si perdono.
      - Restano invariati gli stati della sintesi (Nessuna sintesi, In scrittura, In attesa di nuovo tentativo, Sintetizzata), le loro transizioni, il processo omp proprio che va in parallelo alla rifinitura senza attenderla, i 600 secondi di limite e quando una sintesi fallisce. I modelli di sintesi non si sviluppano.

      ## Code notes

      Commit: 58d947126f08b8c7e4128d08782a627080bde977

      - Modello: `Sources/LARP/Model/CallSummary.swift` (`CallSummary`, `SummaryNextStep`), `SummaryState.swift`; schema in `Sources/LARP/Model/ArchiveStore.swift` (`ArchiveStore.schema`, nessun VersionedSchema). I nuovi campi SwiftData vogliono un default perché i vecchi archivi si aprano (vedi `summaryStateRawValue`); valori sconosciuti ricadono su un default.
      - Prompt e schema: `Sources/LARP/Summary/SummaryRequest.swift` `instructions(language:)`, `summary(from:participants:)` (le righe hanno già number/start/end). Le risposte omp si leggono estraendo il `{…}` più esterno.
      - Stato e avvio: `Sources/LARP/Call/CallSummaryStateMachine.swift` (tabella pura `target(from:on:)`), `Sources/LARP/Call/CallLifecycle+Summary.swift` `startSummary`, `finishSummary`, `canSummarize`. Sintesi e rifinitura possono finire in qualunque ordine.
      - Impostazioni: chiave nuova `settings.summaryLanguage` in `Sources/LARP/Settings/SettingsKey.swift`; controller sul modello di `Sources/LARP/Settings/CallSummariesController.swift` (`@MainActor @Observable final class`, `static let shared`, `UserDefaults` iniettato, un metodo per evento con doc comment che cita l'evento).
      - Lingue: `TranscriptionLanguage` in `Sources/LARP/Settings/LanguageAvailability.swift` (it-IT, en-US).
      - `SummaryContent` (`Sources/LARP/Archive/SummaryContent.swift`) è l'unica fonte per vista, ricerca ed export: andrà adeguato ai nuovi campi (la resa la cura un altro Task).
      - Test: `CallSummaryTests`, `CallSummaryStorageTests`, `CallSummariesTests`, `SummaryContentTests`; fake in `Tests/LARPTests/CallLifecycleFakes.swift`.
  ncj5cmwg:
    title: Domande e traduzioni omp
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
    technical: false
    proposal: m8gfdshl
    label: 'Redesign: sintesi e omp'
    finished: 2026-11-11T16:34:34.609Z
    body: |-
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
---
# Sintesi strutturata e domande omp

Sintesi con frase d'apertura, decisioni, azioni, aperti e concetti chiave; lingua della sintesi; domande, risposte e traduzione della trascrizione con omp.
