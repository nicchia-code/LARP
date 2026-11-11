---
refs:
  - shortcuts
  - specs#frameworks
  - user.CHANGE_SHORTCUT
  - user.CLEAR_SHORTCUT
---
# Scorciatoie globali

Due scorciatoie da tastiera globali, che funzionano qualunque app sia in primo piano, modificabili e cancellabili dalle Impostazioni.

## Cosa deve valere

- **Avvia o ferma la registrazione** (default ⌥⌘R): a riposo o dopo "Non questa" avvia una registrazione a mano (dopo "Non questa", legata all'app della proposta scartata se usa ancora il microfono); con una proposta mostrata la accetta; durante una registrazione la ferma.
- **Aggiungi segnalibro** (default ⌥⌘B): durante una registrazione aggiunge un segnalibro alla call registrata, al tempo trascorso; con la pagina di una call mostrata, audio caricato e in riproduzione o in pausa, al tempo raggiunto; altrimenti non fa nulla.
- Ogni scorciatoia ha una combinazione o nessuna. Quelle con una combinazione sono registrate presso macOS senza chiedere il permesso di Accessibilità (Carbon, `RegisterEventHotKey`), registrate di nuovo a ogni cambio e tolte quando rimosse; la registrazione sta dietro un'interfaccia sostituita nei test.
- CHANGE_SHORTCUT: se la combinazione non è quella dell'altra scorciatoia e macOS la accetta, viene salvata e sostituisce la precedente; se è dell'altra o macOS la rifiuta, resta la precedente e sotto la riga compare in `#B42A18` "Già usata da un'altra scorciatoia" o "Combinazione non disponibile". CLEAR_SHORTCUT: niente combinazione, scelta salvata.
- Sezione **Scorciatoie** delle Impostazioni: "Avvia o ferma la registrazione" e "Aggiungi segnalibro", ciascuna con la combinazione in un riquadro ink con testo lime in JetBrains Mono, o "Nessuna" in un riquadro outline; un clic sul riquadro attende la nuova combinazione ("Premi i tasti…"), Esc annulla, Delete la rimuove.
- La combinazione di avvio compare accanto a "Registra", "Registra questa call" e "Nuova registrazione"; quella del segnalibro accanto a "Segnalibro" della finestra dal vivo: con "Nessuna" non si mostra nulla.
- Salvataggio in `settings.shortcutRecord` e `settings.shortcutBookmark`: codice del tasto e modificatori, o "none" se rimossa; assente vale il default.

## Code notes
Commit: 58d947126f08b8c7e4128d08782a627080bde977
- Spec: framework Carbon, `RegisterEventHotKey`, scelto perché non serve Accessibilità né pacchetti di terze parti.
- Avvio/stop e proposta: `Sources/LARP/Capture/Recorder.swift` (`startRecording`, `acceptProposal`, stop); il bookmark passa per quanto aggiunto dal Task dei segnalibri e dal `PlaybackController` (`Sources/LARP/Playback/PlaybackController.swift`) per sapere se l'audio è caricato.
- Chiavi in `Sources/LARP/Settings/SettingsKey.swift`; pagina impostazioni `Sources/LARP/Settings/SettingsView.swift`.
- Convenzione: `@MainActor @Observable final class` con `static let shared`, dipendenze dietro protocolli (un fake per la registrazione presso macOS), `UserDefaults` iniettato, test Swift Testing in suite `.serialized`.
- Nuovi file in `Sources/LARP/` sono presi senza toccare `project.yml`; per Carbon serve solo l'import.
- Wiring in `Sources/LARP/App/LARPApp.swift` `init()`.
