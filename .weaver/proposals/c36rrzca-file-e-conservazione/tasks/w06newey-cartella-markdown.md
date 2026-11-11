---
refs:
- markdown-folder
- requirements/rules#markdown-folder
- requirements/tech#markdown-folder
- user.TURN_ON_MARKDOWN_FOLDER
- user.CHOOSE_MARKDOWN_FOLDER
- user.TURN_OFF_MARKDOWN_FOLDER
---
# Cartella Markdown

Ogni call pronta può essere tenuta come file Markdown, uno per call, in una cartella scelta dall'utente, con lo stesso contenuto dell'esportazione Markdown. I file si scrivono solo sul Mac. La funzione è spenta di default.

## Cosa deve valere

- **Off** (iniziale, salvo che la cartella sia rimasta accesa): nessun file viene scritto; i file scritti prima restano dove sono.
  - Accendendo "Cartella Markdown" si apre il pannello di sistema per scegliere una cartella: scelta una cartella, la scelta è salvata, si passa a On e tutte le call pronte vengono scritte subito; annullando il pannello resta Off.
- **On**:
  - Scegliendo un'altra cartella ("Cambia"), la scelta è salvata, i file nella cartella precedente restano dove sono e tutte le call pronte vengono scritte subito nella nuova.
  - Spegnendo, la scelta è salvata e si passa a Off; i file scritti restano.
  - Quando una call diventa pronta il suo file viene scritto, sostituendo quello che aveva.
  - Il file viene riscritto, solo per una call pronta, quando: la sintesi viene scritta; un partecipante viene rinominato; una riga viene corretta; la trascrizione viene ripristinata; un'azione viene spuntata o tolta; una nota viene aggiunta, modificata o cancellata; un segnalibro viene aggiunto o cancellato.
  - Rinominando una call pronta il file prende il nuovo nome e quello con il vecchio nome viene rimosso.
  - Quando una call viene eliminata il suo file viene rimosso dalla cartella.
- Una call conta come pronta per la cartella solo quando è nello stato Ready; in ogni altro stato viene scritta quando diventa pronta.
- Nome del file: come il nome predefinito dell'esportazione con `.md` aggiunto; quando un'altra call della cartella usa già quel nome si aggiunge " (2)", " (3)" e così via prima di `.md`. Il nome usato da ogni call è conservato con la call (assente finché non è scritto), per poterlo rinominare o rimuovere; un file non viene mai rimosso né rinominato se non è stato scritto da LARP per quella call.
- Contenuto: l'esportazione Markdown della call, nella lingua dell'interfaccia al momento della scrittura.
- Quando un file non si può scrivere si riprova al cambio successivo di quella call; la cartella resta accesa e le Impostazioni mostrano "Impossibile scrivere nella cartella" sotto la riga finché una scrittura non riesce.
- La cartella si sceglie con il pannello di apertura di sistema; il percorso è conservato così com'è (l'app non è sandboxed) nell'impostazione della cartella Markdown, la cui assenza significa spenta. I file si scrivono in modo atomico, fuori dal thread principale, una call alla volta, in UTF-8.
- Fanno parte di questa Task il salvataggio dell'impostazione e il campo con il nome del file della call; la riga "Cartella Markdown" della pagina Impostazioni (interruttore, percorso, "Cambia", messaggio d'errore) è nella Task "Privacy e archivio", che ne mostra lo stato.

## Code notes
Commit: 58d947126f08b8c7e4128d08782a627080bde977
- Contenuto e nome: `Sources/LARP/Archive/TranscriptExport.swift` (`TranscriptExport.markdown(for:)`, `defaultFileName`, `ArchiveFormat`), `MarkdownDocument.swift`; `SummaryContent` è l'unica fonte della sintesi per vista, ricerca ed export: estenderla, non duplicarla.
- Chiavi: `Sources/LARP/Settings/SettingsKey.swift`; controller come gli altri in `Sources/LARP/Settings/` (`@MainActor @Observable final class` con `static let shared`, dipendenze dietro protocolli con `@ObservationIgnored`, un metodo per evento del Model con doc comment che nomina evento e transizione; tabella di transizione pura).
- Eventi della call: `Sources/LARP/Call/CallLifecycle.swift` (`enter(_:call:)`, `renameCall`, `renameParticipant`, `delete`), `CallLifecycle+Refinement.swift`, `CallLifecycle+Summary.swift`. Settings non dipende dallo strato call: il cablaggio è in `Sources/LARP/App/LARPApp.swift` `init()`. Notizie tra parti via `EventBroadcaster<T>`.
- Dati: `Sources/LARP/Model/Call.swift`; i nuovi campi SwiftData devono avere un default (come `summaryStateRawValue`) per aprire store vecchi.
- Test: `UserDefaults` iniettato con suite isolate (`makeDefaults()`), suite Swift Testing `.serialized`; fake come in `Tests/LARPTests/CallLifecycleFakes.swift`.
