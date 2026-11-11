---
technical: true
refs:
  - requirements/ui#General
  - requirements/tech#General
  - requirements/rules#call
---
# Fondamenta visive e lingue

Prepara il linguaggio visivo comune e le due lingue dell'interfaccia, su cui si appoggiano tutte le schermate ridisegnate. Il linguaggio visivo della Style Guide si segue alla lettera e sostituisce del tutto l'aspetto attuale.

## Cosa deve valere alla fine

- Un unico strato condiviso definisce una volta sola la palette, i tre font, gli stili di testo e i componenti (pulsanti primario lime, scuro, outline, distruttivo e link; chip e chip di stato; switch 36 × 22; card chiare e scure; campi e campo di ricerca; box di scelta; avatar con anello; eyebrow; tasti delle scorciatoie; forme d'onda a barre) con le misure e i colori della Requirement di interfaccia generale. Nessuna vista usa il colore d'accento di sistema né gli stili standard di pulsanti, switch, liste e form; niente traslucenza, materiali, sfocature o vetro sulle superfici di LARP; il focus dei controlli personalizzati è un contorno di 2 px lime o ink.
- Palette fissa come nel mockup, identica anche con il Mac in modalità scura: ogni superficie imposta da sé il proprio aspetto (chiaro su carta e bianco, scuro su ink) così che i controlli di sistema al suo interno si disegnino bene. Il lime non è mai testo su superfici chiare, né lo è `#A3A69B`.
- I colori dei parlanti sono gli stessi ovunque: "Io" ink con iniziale bianca su chiaro e bianco con iniziale ink su scuro; i partecipanti per numero lime, lilla, pesca, azzurro e poi di nuovo da lime; "Altri" nel complesso `#A3A69B`; testo ink sui colori dei partecipanti.
- Inter, Bricolage Grotesque e JetBrains Mono sono inclusi nell'app come file TTF o OTF con i testi della loro licenza SIL OFL e registrati all'avvio; i file web della Style Guide non si usano.
- Il marchio LARP segue la griglia della Requirement: l'icona dell'app è il quadrato lime con barre ink, in un catalogo di asset; l'icona della barra dei menu è disegnata nel codice come immagine colorata (quadrato ink con barre lime), uguale con barra chiara o scura, come il punto rosso della registrazione. Le forme d'onda in movimento si fermano quando il Mac chiede di ridurre il movimento.
- Interfaccia in italiano o inglese secondo la lingua del sistema (o quella scelta per LARP nelle Impostazioni di Sistema); inglese quando non è nessuna delle due. Ogni testo mostrato all'utente esiste in italiano e inglese in un unico catalogo di stringhe, con l'italiano come lingua di sviluppo; i testi segnaposto inglesi del designer sono sostituiti dai testi reali di LARP.
- I testi costruiti nel codice (stati, titoli predefiniti, nomi dei parlanti, titoli delle sezioni della sintesi, esportazione Markdown, avvisi) sono localizzati come quelli delle viste, e date e ore usano il locale della lingua dell'interfaccia. Si mostrano nella lingua attuale dell'interfaccia; i dati salvati non cambiano.
- Titolo predefinito, costruito quando si mostra: "Call del <giorno> <mese> <anno>, <hh>:<mm>" per una call legata a un'app di call e "Registrazione del …" per una registrazione avviata a mano, mese italiano in minuscolo; in inglese "Call on …" e "Recording on …" con il mese inglese. Giorno non riempito, ore (24 ore) e minuti a due cifre, nel calendario del Mac.
- Nomi dei parlanti nella lingua dell'interfaccia: "Io" / "Me", "Altri" / "Others", il nome dato dall'utente oppure "Partecipante <numero>" / "Participant <numero>"; una riga dei partecipanti senza partecipante mostra "Altri" / "Others". Ciò che omp riceve e risponde resta con i nomi italiani "Io" e "Partecipante <numero>" qualunque sia la lingua dell'interfaccia. Titoli e nomi digitati si salvano senza spazi attorno; vuoti ripristinano il predefinito.

## Code notes
Commit: 58d947126f08b8c7e4128d08782a627080bde977
- Oggi tutto il testo UI è italiano e scritto a mano, senza String Catalog: va introdotto.
- `Sources/LARP/Call/CallNaming.swift`: `displayTitle`, `defaultTitle`, `normalizedName`, `Participant.displayName`, `speakerName`.
- `Sources/LARP/Archive/TranscriptExport.swift`: `ArchiveFormat` (locale `it_IT` fisso, formati clock/durata), `markdown(for:)`.
- `Sources/LARP/Archive/SummaryContent.swift:117`: `SummaryContent.Titles` (titoli it/en già presenti), fonte unica per vista, ricerca ed export.
- `Sources/LARP/Archive/CallState+Label.swift` `statusLabel`, `CallLifecycle+Transcription.swift` `statusLabel(of:)`: stringhe di stato italiane.
- `Sources/LARP/Refinement/RefinementRequest.swift` `RefinementSpeaker` e `Summary/SummaryRequest.swift`: devono restare con "Io"/"Partecipante N".
- `Sources/LARP/Capture/MenuBarLabel.swift`: `recordingDot`, `NSImage` non template riusabile per l'icona colorata.
- Risorse e font sono presi per cartella sotto `Sources/LARP/`; chiavi Info.plist solo in `info.properties` di `project.yml`, mai in `Config/Info.plist`.
- Colori dei parlanti: mappatura stabile da `Participant.number`, `.me` ink.
- Niente infrastruttura di test UI: testare formattatori e testi costruiti (`TranscriptExportTests`, `SummaryContentTests`).
- Aggiornare README ("Layout", la riga sull'icona microfono) e la frase "The interface is in Italian".
