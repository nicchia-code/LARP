---
refs:
  - settings
  - launch-at-login
  - assistant-status
  - requirements/ui#settings
  - requirements/rules#launch-at-login
  - user.OPEN_SETTINGS
---
# Pagina delle Impostazioni

Le Impostazioni lasciano la loro finestra e diventano una pagina della finestra principale, con il nuovo linguaggio visivo. La schermata della Style Guide (06 Settings) è allegata a questo Task.

## Cosa deve valere alla fine

- `user.OPEN_SETTINGS` (da "Impostazioni" della finestra a comparsa, della barra laterale o con ⌘,) porta l'app in primo piano e mostra la finestra principale sulle Impostazioni; se una call era mostrata, la pagina viene lasciata e il suo audio scaricato.
- La barra laterale mostra "‹ Archivio" in alto e i nomi delle sezioni; il clic su un nome porta in vista la sua sezione, e quella scelta è disegnata come l'elemento scelto dell'Archivio.
- La pagina ha l'eyebrow "Impostazioni", il titolo "Fallo tuo." e le sezioni come card bianche in due colonne (una sotto i 900 px); ogni riga ha etichetta, spiegazione facoltativa e il controllo a destra.
- **Trascrizione**: "Motore" con il solo valore "Sul Mac" come segmento ink selezionato e "L'audio non lascia il computer" (la trascrizione cloud non si sviluppa); "Lingua" Italiano / English con lo stato del modello vocale ("Verifica in corso…", "Download in corso…", "Non disponibile, nuovo tentativo appena possibile", "Pronta") e "Vale per le registrazioni che iniziano dopo la scelta."; "Rifinisci il testo con omp" con uno switch.
- **Sintesi**: "Sintetizza quando la call finisce" con uno switch e "Sintesi, decisioni e prossimi passi scritti da omp".
- Sotto ogni interruttore di omp acceso compare lo stato di omp: "Verifica in corso…", "omp pronto" o "omp non trovato" (in `#B42A18`); omp si cerca solo mentre almeno uno dei due è acceso e conta solo l'ultimo controllo.
- **Scorciatoie**: "Apri LARP all'accesso" con uno switch e "Resta discreto nella barra dei menu"; lo switch appare acceso quando l'elemento di login è attivo o in attesa di approvazione, e in attesa compare "Approva LARP in Impostazioni di Sistema › Generali › Elementi login.". Se registrare o togliere fallisce compare "Impossibile cambiare l'avvio all'accesso: <errore>" (inglese "Couldn't change opening at login: <error>") in `#B42A18` e lo stato reale si rilegge.
- Ogni scelta resta tra un avvio e l'altro; il comportamento delle impostazioni non cambia.

## Code notes
Commit: 58d947126f08b8c7e4128d08782a627080bde977
- `Sources/LARP/Settings/SettingsView.swift` (`.formStyle(.grouped)`, `.frame(width: 440)`, `statusText`, `assistantText`): da rifare come pagina. Prende `LaunchAtLogin` come `@State`, non condiviso.
- `Sources/LARP/App/LARPApp.swift`: scena `Settings { SettingsView() }` da togliere; ⌘, deve aprire la finestra principale. `init()` collega `start`/`appLaunched`.
- `Sources/LARP/App/MenuBarContent.swift`: `SettingsLink` con `NSApp.activate()` (serve per app agent).
- `Sources/LARP/Settings/AssistantStatusController.swift` `openSettings()`, `appLaunched()`; `TranscriptionLanguageController.swift` (contatore `generation`, `evaluate()`); `TranscriptRefinementController.swift`, `CallSummariesController.swift`; `LaunchAtLogin.swift` (`LoginItem`, `MainAppLoginItem`).
- Macchine `@MainActor @Observable final class` con `static let shared`, dipendenze dietro protocolli; test in `Tests/LARPTests/LaunchAtLoginTests`, `TranscriptionLanguageTests` (`FakeLoginItem`, `makeDefaults()`).
