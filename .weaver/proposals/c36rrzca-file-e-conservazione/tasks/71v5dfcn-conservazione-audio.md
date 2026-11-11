---
refs:
- audio-retention
- call
- playback
- time.AUDIO_RETENTION_CHECK_DUE
- requirements/rules#audio-retention
- requirements/tech#audio-retention
- requirements/data#call
- user.CHOOSE_AUDIO_RETENTION
---
# Conservazione dell'audio

L'utente sceglie per quanto tempo si tiene l'audio delle call: "Sempre" (default), "Per 30 giorni" o "Per 90 giorni", contati dall'inizio di ogni call; un giorno vale 24 ore. Scaduto il tempo, i file audio di una call pronta si cancellano dal Mac; trascrizione, sintesi, note, segnalibri e forma d'onda restano, e la call non si può più ascoltare.

## Cosa deve valere

- **Tieni sempre** (iniziale, salvo che sia stato scelto un limite): l'audio resta finché la call non viene eliminata.
  - Scegliendo 30 o 90 giorni la scelta è salvata, si passa a **Tieni per un tempo** e l'audio delle call pronte più vecchie viene cancellato subito; scegliendo "Sempre" non cambia nulla.
- **Tieni per un tempo**: scegliendo l'altro numero di giorni la scelta è salvata e l'audio delle call pronte più vecchie del nuovo limite viene cancellato subito; scegliendo "Sempre" la scelta è salvata e l'audio già cancellato non torna.
- Il controllo avviene all'avvio, dopo che ogni altro lavoro dell'avvio è partito, poi ogni ora mentre l'app è aperta, e subito dopo una nuova scelta. Per ogni call vale solo se: l'audio è tenuto per un tempo limitato, la call è nello stato Ready, è iniziata da più di quel tempo, ha ancora il suo audio e la sua sintesi non è in scrittura. Una call saltata viene guardata di nuovo al controllo successivo.
- Si cancellano solo i due file audio della call (microfono e audio di sistema), mai altro contenuto della sua cartella; la call resta Ready e conserva che il suo audio è stato rimosso, con il numero di giorni in vigore in quel momento.
- Una call con l'audio rimosso: la forma d'onda non cambia; non si può riprodurre né le si può aggiungere un segnalibro ascoltando; la barra di riproduzione dice "Audio eliminato dopo <n> giorni" al posto di "Audio non disponibile", con <n> i giorni della conservazione in vigore quando fu rimosso. La riproduzione resta ferma: avviarla, cliccare una frase, un segnalibro o una decisione non la fa partire.
- Dati: l'impostazione dei giorni di conservazione vale 30 o 90; assente significa "Sempre" e ogni altro valore si legge come "Sempre". Il segno di audio rimosso con i giorni è un campo opzionale della call (default no), così uno store salvato prima si apre senza.
- Tecnica: il controllo orario gira su un timer dell'app mentre è aperta; i file si rimuovono con il file manager dell'archivio, fuori dal thread principale, e il segno sulla call è salvato sul thread principale.
- La scelta "Conserva i file audio" nella pagina Impostazioni è nella Task "Privacy e archivio"; qui servono la scelta salvata e il comportamento.

## Code notes
Commit: 58d947126f08b8c7e4128d08782a627080bde977
- Call: `Sources/LARP/Call/CallStateMachine.swift` (`CallStateMachine.target`, `CallEvent`: tabella pura, gli eventi portano i fatti delle guardie); effetti in `Sources/LARP/Call/CallLifecycle.swift` (`apply(_:to:)`, `enter(_:call:)`); avvio cablato in `Sources/LARP/App/LARPApp.swift` `init()` (start/appLaunched).
- Stato sintesi: `Sources/LARP/Model/SummaryState.swift`. Dati: `Sources/LARP/Model/Call.swift` (percorsi audio relativi), `Sources/LARP/Model/AppPaths.swift`, `ArchiveStore.swift`. Nuovi campi SwiftData con default (come `summaryStateRawValue`); valori grezzi sconosciuti ricadono su un default.
- Chiavi: `Sources/LARP/Settings/SettingsKey.swift`; controller come gli altri in `Sources/LARP/Settings/` (`@MainActor @Observable`, `static let shared`, dipendenze dietro protocolli).
- Riproduzione: `Sources/LARP/Playback/PlaybackController.swift` (`show`, `seek`, `play(fromSentenceStart:)`), `PlaybackControlsView.swift` per il testo della barra.
- Il lavoro sul Model avviene sul main actor; le dipendenze esterne (file manager, timer) dietro protocolli con fake in `Tests/LARPTests/CallLifecycleFakes.swift`. Test pertinenti: `CallManagementTests`, `ArchiveStoreTests`.
