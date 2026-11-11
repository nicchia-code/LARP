---
refs:
- call-summary
- summary-language
- requirements/data#call-summary
- requirements/rules#call-summary
- user.CHOOSE_SUMMARY_LANGUAGE
- user.TOGGLE_ACTION_ITEM
---
# Nuova struttura della sintesi

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
