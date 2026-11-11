---
status: approved
kind: import
requires:
- 5zk696pr
base:
  model/settings/assistant-status.md: new
  model/settings/call-summaries.md: new
  model/settings/feature.md: new
  model/settings/launch-at-login.md: new
  model/settings/transcript-refinement.md: new
  model/settings/transcription-language.md: new
  requirements/data/settings.md: new
  requirements/rules/settings.md: new
  requirements/tech/settings.md: new
created: 2026-11-11T12:33:57.103Z
label: Import
job: a8nt702p
---
# Import: Settings

Importa la Feature `settings` da `Sources/LARP/Settings/` (controller della lingua di trascrizione, degli interruttori di rifinitura e sintesi, dello stato di omp, dell'avvio all'accesso, monitor di rete, chiavi delle impostazioni, finestra delle impostazioni) e dalla verifica di omp in `Sources/LARP/Assistant/Omp.swift` e `OmpLocator.swift`, con il collegamento in `Sources/LARP/App/LARPApp.swift` e i test in `Tests/LARPTests/`. Cinque Machine: `transcription-language`, `transcript-refinement`, `call-summaries`, `assistant-status`, `launch-at-login`; Requirements `data`, `rules` e `tech` della Feature.

## Doubts
- `TranscriptionLanguageController` emette `LANGUAGE_READY` solo per la lingua scelta: una chiamata registrata in una lingua il cui modello mancava resta in attesa se l'utente sceglie poi l'altra lingua, e `CallLifecycle.appLaunched()` non riprende le chiamate in attesa della lingua.
- `LaunchAtLogin.refresh()` scrive `settings.launchAtLogin` ma nessun punto del codice legge quel valore (dato morto).
- `AssistantStatusController.turnedOn()`: accendere il secondo interruttore mentre omp risulta mancante non lo cerca di nuovo; nemmeno il ritorno della rete lo fa: si riprova solo all'avvio o all'apertura delle impostazioni.
- `AssistantStatusController.init` parte in verifica quando un interruttore è acceso senza avviare alcuna verifica finché non arriva `appLaunched()`.
- `LARPApp.init` chiama `TranscriptionLanguageController.start()` prima che `CallLifecycle.start()` si iscriva a `languageReady`: funziona solo perché la verifica parte dopo la fine di `init`; ordine fragile.
- Cambiando lingua durante un download, `AppleSpeechModels.install` può proseguire in background; il risultato viene ignorato, ma non è determinato se il download venga davvero interrotto.
