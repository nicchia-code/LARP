---
refs:
  - onboarding
  - settings
  - transcription-language
  - transcript-refinement
  - call-summaries
  - assistant-status
  - requirements/ui#onboarding
  - requirements/ui#settings
  - requirements/data#settings
  - user.ALLOW_MICROPHONE
  - user.ALLOW_SYSTEM_AUDIO
  - user.CONTINUE_SETUP
  - user.FINISH_SETUP
  - user.CHOOSE_LANGUAGE
  - user.TURN_ON_REFINEMENT
  - user.TURN_OFF_REFINEMENT
  - user.TURN_ON_SUMMARY
  - user.TURN_OFF_SUMMARY
---
# Benvenuto e Impostazioni

Schermata di benvenuto al primo avvio in due passi, e pagina delle Impostazioni con le nuove righe.

## Cosa deve valere

- **Benvenuto**: al primo avvio di una versione che la ha, se non è mai stata conclusa su questo Mac, l'app viene in primo piano e si apre la schermata sul passo dei permessi. Conclusa una volta, non ricompare mai; tutto ciò che contiene resta nelle Impostazioni.
  - **Passo 1 di 2 · Permessi**: righe "01" microfono ("La tua voce nella conversazione") e "02" audio di sistema ("Tutti gli altri, da Teams, Zoom, Meet e ogni altra app"), ciascuna con "Consenti" o il chip lime "✓ Consentito" una volta concesso. ALLOW_MICROPHONE chiede il permesso se non ancora deciso; ALLOW_SYSTEM_AUDIO lo chiede creando e distruggendo un tap dell'audio di sistema; se era stato rifiutato, si apre il pannello giusto di Impostazioni di Sistema. "Continua →" va avanti anche con un permesso mancante.
  - **Passo 2 di 2 · Scelte**: la lingua di trascrizione come due grandi card "Italiano"/"English" con sotto lo stato del modello vocale, gli interruttori "Rifinisci il testo con omp" e "Sintetizza quando la call finisce" con lo stato di omp mentre uno è acceso, come nelle Impostazioni, la riga "Sul Mac: l'audio non lascia il computer" e "Inizia →".
  - FINISH_SETUP con "Inizia" o chiudendo la finestra (assunzione dell'agente: chiuderla vale come completarla): la schermata si chiude e il fatto è salvato.
  - Aspetto: circa 960 × 680 px, non ridimensionabile, senza barra del titolo; a sinistra pannello ink (circa 45 %) con marchio, titolo "Ogni call," / "messa agli atti." su banda lime, la riga descrittiva e una forma d'onda di 60 barre; a destra, su carta, il passo, con "Tutto si può cambiare più tardi nelle Impostazioni.".
- **Impostazioni**, sezioni in questo ordine: **Registrazione** ("Rileva le call", "App da sorvegliare" con un chip per app nota, Microsoft Teams per primo, disattivati a rilevamento spento, "Registra automaticamente le call rilevate", "Microfono"); **Trascrizione** ("Motore" fisso "Sul Mac", "Lingua" con lo stato del modello e "Vale per le registrazioni che iniziano dopo la scelta.", "Rifinisci il testo con omp" con lo stato di omp); **Sintesi**; **Scorciatoie** con le due scorciatoie e "Apri LARP all'accesso". Lo stato di omp: "Verifica in corso…", "omp pronto", "omp non trovato" (in `#B42A18`).
- La lingua, la rifinitura e la sintesi scelte nel benvenuto valgono esattamente come nelle Impostazioni (stesse conseguenze per le call in attesa e per il controllo di omp).
- Ogni scelta è conservata tra gli avvii; `settings.onboardingDone` (default no) dice se il benvenuto è stato concluso. Gli stati del controllo lingua, di omp e del login item restano in memoria.

## Code notes
Commit: 58d947126f08b8c7e4128d08782a627080bde977
- Impostazioni: `Sources/LARP/Settings/SettingsView.swift` (`statusText`, `assistantText`; prende `LaunchAtLogin` come `@State`, non condiviso); chiavi `SettingsKey.swift`.
- Controller da riusare: `TranscriptionLanguageController.swift` (contatore `generation`, `evaluate()`, `readyEvents`), `TranscriptRefinementController.swift` (`turnOffEvents`), `CallSummariesController.swift`, `AssistantStatusController.swift` (`openSettings()`, `appLaunched()`), tutti in `Sources/LARP/Settings/`.
- Permessi: `Sources/LARP/Capture/SystemRecordingPermissions.swift` `missingPermission(requireSystemAudio:)`; alert e pannelli di Impostazioni di Sistema nel Recorder.
- Finestra: scena in `Sources/LARP/App/LARPApp.swift` `body`/`init()`; per un'app `LSUIElement` serve `NSApp.activate()` prima di `openWindow`.
- Convenzioni: `@MainActor @Observable final class` con `static let shared`, dipendenze dietro protocolli, `UserDefaults` iniettato; fake in `Tests/LARPTests/TranscriptionLanguageTests.swift` (`FakeSpeechModels`, `makeDefaults()`), suite `.serialized`.
- Nessun test UI: verificare a mano l'aspetto, testare la logica dei passi.
