---
refs:
- main-window
- playback
- library
- settings
- requirements/ui#main-window
- requirements/ui#settings
- requirements/rules#main-window
- requirements/data#settings
- user.SHOW_ACTIONS_VIEW
- user.SELECT_DECISION
---
# Pagina sintesi e vista Azioni

La finestra principale mostra la nuova sintesi sulla pagina della call, ha la vista "Azioni" di tutte le call, i campi per domande e traduzione, e le Impostazioni hanno le nuove voci della sezione Sintesi; ricerca, card ed esportazione Markdown seguono la nuova sintesi.

## Cosa deve valere

- **Barra laterale**: la voce "Azioni" sta fra "Tutte le call" e "Segnalibri", disegnata come loro, e apre la vista Azioni.
- **Vista Azioni**: titolo "Azioni"; le azioni delle sintesi delle call che corrispondono alla ricerca, raggruppate per call dalla più recente; dentro una call prima le non fatte, poi le fatte barrate, ciascuna nell'ordine della sintesi con spunta, testo, responsabile con il nome attuale del partecipante e scadenza come detta. Una card bianca per call con eyebrow (giorno, ora, app) e titolo in Bricolage Grotesque 19 px, righe come sulla pagina della call, le fatte barrate in `#5A5D55` su `#F1F1EA`. Spuntare qui equivale a spuntare sulla pagina della call; un clic fuori dalla spunta (sulla call o su un'azione) apre la pagina della call sulla sintesi e ne carica l'audio. Senza azioni: "Nessuna azione".
- **Sintesi sulla pagina della call**: lo stato e, quando c'è, la frase d'apertura in Inter 24 px medium con la parte chiave su sfondo lime `#D4F24A`; poi "Decisioni" numerate "01", "02" con a destra l'ora della riga in un chip JetBrains Mono che fa partire l'audio da lì; "Azioni" in card bianche con spunta quadrata da 18 px, testo (barrato quando fatta), avatar del responsabile con "<nome> · <scadenza>"; "Rimasto aperto"; "Concetti chiave"; "Altro" solo se non vuoto. "Sintetizza"/"Rigenera" come oggi; una sintesi scritta mentre la pagina è aperta compare senza cambiare pagina.
- **Clic su una decisione**: solo se la call ha audio da riprodurre, la riproduzione parte dall'inizio della riga in cui la decisione è stata presa (da ferma, in pausa o in riproduzione).
- **Testi**: titoli delle sezioni nella lingua dell'interfaccia: "Decisioni", "Azioni", "Rimasto aperto", "Concetti chiave", "Altro", lista vuota "Nessuno" / "Decisions", "Action items", "Left open", "Key concepts", "Other", "None"; gli elementi restano nella lingua della sintesi. Ogni "Partecipante <numero>" si sostituisce col nome dato, se non vuoto, o con "Participant <numero>" in inglese; la sintesi salvata non cambia mai. Una sintesi di prima mostra le prossime azioni come azioni senza scadenza e niente rimasto aperto.
- **Card**: mostra la frase d'apertura della sintesi (vuota: lo stato della call) e, con azioni non fatte, la chip "1 azione"/"<n> azioni" ("1 action"/"<n> actions").
- **Ricerca**: cerca anche nella sintesi come mostrata (frase d'apertura, titoli, elementi, responsabili, scadenze, testo libero, con i nomi attuali), qualunque sia lo stato della sintesi e anche a sintesi spente; la parola della lista vuota non si cerca.
- **Domande**: in fondo alla colonna sinistra, sotto le schede, domande (13 px semibold) e risposte (15 px), l'ultima con "omp sta rispondendo…" mentre attende, una fallita con il link "Riprova"; poi il campo scuro "Chiedi qualcosa a questa call", alto 52 px, raggio 26, con il pulsante lime "Chiedi" disattivato mentre omp risponde. Si mostra solo con l'interruttore acceso.
- **Traduzione**: nel pannello della trascrizione il link "Traduci" fra "Modifica testo" e "Copia trascrizione"; legge "Traduzione in corso…" mentre omp traduce e "Mostra originale" a traduzione mostrata, con l'eyebrow "TRADOTTO IN <LINGUA>" sotto il titolo del pannello; un fallimento mostra "Traduzione non riuscita" in `#B42A18` accanto al link. Una domanda o traduzione in corso si annulla uscendo dalla pagina della call.
- **Markdown** (esportazione, "Copia sintesi"): la parte Sintesi ha la frase d'apertura come paragrafo con la parte chiave in `**grassetto**`, poi per sezione `### <titolo>` con `- <elemento>`, le decisioni come `- [<orologio>] <testo>`, le azioni come `- [x] <elemento>` o `- [ ] <elemento>` (elemento = testo, ` · <responsabile>`, ` · <scadenza>`), o la parola della lista vuota, o il testo libero; poi note, segnalibri e trascrizione come già definiti.
- **Impostazioni, sezione Sintesi**: "Sintetizza quando la call finisce" con lo stato di omp sotto quando è acceso; "Lingua della sintesi" con "Come la call", "Italiano", "English" (salvata, default "Come la call"); "Domande e traduzioni con omp" con interruttore, spiegazione "Chiedi qualcosa a una call e traducine la trascrizione" e, da acceso, lo stato di omp sotto (salvato, spento di default).

## Code notes

Commit: 58d947126f08b8c7e4128d08782a627080bde977

- Pagina call: `Sources/LARP/Archive/CallDetailView.swift` (`.id(call.id)`, lo stato si azzera per call), `CallSummaryView.swift` (`CallSummaryView`, `SummarySectionView`), `TranscriptView.swift`, card `CallRow.swift`, finestra `ArchiveView.swift`.
- `Sources/LARP/Archive/SummaryContent.swift` è l'unica fonte per vista, ricerca ed export (`Words`, `replacingParticipants`, `markdownParagraphs`, `searchableTexts`, `Titles` it/en alla riga 117): estenderlo, non duplicarlo. Ricerca `CallSearch.swift` (`normalized`, `fields`); export `TranscriptExport.swift` (`markdown(for:)`, `ArchiveFormat` per l'orologio), `MarkdownDocument.swift`.
- Riproduzione da una riga: `Sources/LARP/Playback/PlaybackController.swift` `play(fromSentenceStart:)`, `seek`.
- Impostazioni: `Sources/LARP/Settings/SettingsView.swift` (`assistantText`).
- Nei commenti delle viste citare gli eventi del Model (`user.SHOW_ACTIONS_VIEW`, `user.SELECT_DECISION`). Il colore dei parlanti va mappato in modo stabile da `Participant.number`, `.me` inchiostro.
- Niente test UI: si verifica a mano; testare solo la logica (SummaryContent, ricerca, export, tabelle): `SummaryContentTests`, `TranscriptExportTests`.
