---
refs:
  - recorder
  - capture
  - call-detection
  - auto-recording
  - requirements/rules#recorder
  - requirements/tech#recorder
  - requirements/ui#recorder
  - requirements/data#capture
  - user.START_RECORDING
  - user.ACCEPT_PROPOSAL
  - user.DISMISS_PROPOSAL
  - user.STOP_RECORDING
  - user.PAUSE_RECORDING
  - user.RESUME_RECORDING
  - user.TURN_ON_CALL_DETECTION
  - user.TURN_OFF_CALL_DETECTION
  - user.WATCH_APP
  - user.UNWATCH_APP
  - user.TURN_ON_AUTO_RECORDING
  - user.TURN_OFF_AUTO_RECORDING
---
# Proposta, pausa, auto-registrazione

Il Recorder segue il nuovo Model: rilevamento delle call con app sorvegliate, proposta scartabile con "Non questa", registrazione automatica e pausa.

## Cosa deve valere

- **Rilevamento**: una call app che inizia a usare il microfono dà una proposta o una registrazione automatica solo se "Rileva le call" (Call detection) è acceso e l'app è sorvegliata. Ogni app nota è sorvegliata finché l'utente non spegne il suo chip; la scelta di ogni app resta salvata anche a rilevamento spento. Rilevamento acceso di default.
  - Spegnendo il rilevamento la scelta viene salvata, la proposta mostrata (anche quella scartata) sparisce e non partono nuove proposte né registrazioni automatiche; una registrazione in corso continua. Riaccendendolo, le app sorvegliate che già usano il microfono contano come avviate.
  - Sorvegliare un'app a rilevamento acceso: se già usa il microfono conta come avviata. Smettere di sorvegliarla: la proposta mostrata o scartata per quell'app sparisce (assunzione dell'agente: come spegnere il rilevamento), la registrazione in corso continua. A rilevamento spento, il cambio di un chip è solo salvato.
- **Registrazione automatica** ("Registra automaticamente le call rilevate", spenta di default): se accesa e i permessi del microfono e dell'audio di sistema sono già concessi (letti senza chiedere), la call rilevata viene registrata senza proposta, legata alla call app; se un permesso non è ancora concesso compare la proposta. Accenderla lascia la proposta già mostrata; spegnerla lascia continuare la registrazione in corso. Si cambia dalle Impostazioni e dalla finestra a comparsa.
- **Proposta**: card scura "In onda ora · <app>", titolo "Call rilevata", "Registra questa call" con la scorciatoia e "Non questa"; identica nel pannello sotto l'icona (che non prende mai il focus), nella finestra a comparsa al posto della card dello stato e come banner in cima all'Archivio. Mai una seconda proposta.
- **"Non questa"** (DISMISS_PROPOSAL): la proposta sparisce ovunque, niente viene registrato; lo stato "Proposal dismissed" conta come l'unica proposta finché quell'app non smette di usare il microfono, e la finestra a comparsa appare come a riposo ("Pronto quando vuoi"). Se poi l'utente avvia la registrazione ("Registra", "Nuova registrazione" o la scorciatoia) mentre l'app usa ancora il microfono, servono entrambi i permessi, come accettando la proposta, e la registrazione è legata a quell'app; con un permesso mancante l'avviso nomina il primo mancante, microfono prima.
- **Pausa**: "Pausa"/"Riprendi" dalla pillola, dalla finestra dal vivo e dalla finestra a comparsa. In pausa entrambe le tracce si scrivono con silenzio della stessa lunghezza dell'audio catturato, la trascrizione dal vivo riceve lo stesso silenzio, il tempo trascorso continua a contare (i tempi della call restano quelli dell'orologio), i livelli sono vuoti. L'icona della barra dei menu mostra il punto `#A3A69B` invece di `#FF5A40`, la finestra a comparsa dice "In pausa". Una call app legata che smette di usare il microfono termina la registrazione anche in pausa.
- **Finestra a comparsa**: stato "Pronto quando vuoi" / "Call rilevata" / "In registrazione" / "In pausa"; durante la registrazione titolo, tempo, "Pausa"/"Riprendi", "Ferma registrazione" e "Apri finestra dal vivo"; righe "Audio della call" (app della registrazione o della proposta, "—" altrimenti), "Microfono" e l'interruttore della registrazione automatica. "Ferma e sintetizza" non va sviluppato: resta "Ferma".
- Non sviluppato: il promemoria del consenso.
- Le scelte sono salvate in `settings.callDetection` (default sì), `settings.unwatchedCallApps` (nomi delle app spente; nomi non più noti ignorati) e `settings.autoRecording` (default no). Nulla del Recorder è salvato.

## Code notes
Commit: 58d947126f08b8c7e4128d08782a627080bde977
- `Sources/LARP/Capture/Recorder.swift`: `Recorder` (`handle`, `startMonitoring`, `.started` → `.proposing`, `acceptProposal`, `startRecording`, `beginRecording`, `endRecording`); `@Observable`, SwiftUI legge `state` ed `elapsedSeconds`. Serve uno stato per la proposta scartata e un sottostato di pausa.
- `Sources/LARP/Capture/SystemRecordingPermissions.swift`: `missingPermission(requireSystemAudio:)`; per l'automatica serve una lettura senza chiedere.
- `Sources/LARP/Capture/KnownCallApps.swift`: `KnownCallApps.all`, `app(forBundleIdentifier:in:)`; `CoreAudioCallAppMicSource.swift` `refresh()` per le app già attive.
- `Sources/LARP/Capture/RecorderPresenters.swift`: `ProposalPanelController`, `MenuBarPanel`; `Sources/LARP/App/MenuBarContent.swift`, `Capture/MenuBarLabel.swift` (`recordingDot`).
- Chiavi in `Sources/LARP/Settings/SettingsKey.swift`; controller come `@MainActor @Observable final class` con `static let shared`, dipendenze dietro protocolli, `UserDefaults` iniettato (test con `makeDefaults()`), una funzione per evento con commento che cita l'evento del Model.
- Pausa: `Sources/LARP/Recording/TrackPipeline.swift` `process`, `fillSilence`; il silenzio va scritto sulla coda privata della traccia, mai dal thread audio.
- Ogni effetto UI passa da un presenter `@MainActor` dietro protocollo, sostituito nei test.
