---
technical: false
refs:
  - recorder
  - requirements/rules#recorder
  - requirements/tech#recorder
---
# Rilevamento processo responsabile

Un processo che usa il microfono viene attribuito prima di tutto all'app di call che macOS considera responsabile di esso (quella nominata dall'indicatore del microfono di macOS), quando l'identificatore di bundle dell'app responsabile corrisponde a un'app di call della tabella. Questo copre anche helper e servizi avviati dal sistema invece che dall'app (per esempio un helper del microfono di Teams non collegato a Teams come processo padre) e helper di un'app che portano l'identificatore di bundle di un'altra (un helper con prefisso Edge dentro Teams deve contare come Teams, non come Edge).

Se il responsabile non corrisponde a nessuna app, valgono le regole di oggi, nell'ordine: l'identificatore di bundle del processo stesso è uno di quelli dell'app, oppure inizia con uno di essi seguito da un punto (es. `com.google.Chrome.helper`), oppure è uno dei suoi identificatori helper (es. `org.mozilla.plugincontainer`); altrimenti si controllano allo stesso modo i processi padre, fino a 8 livelli, fermandosi al primo processo con identificatore 1 o inferiore. Vince la prima app della tabella che corrisponde.

Il processo responsabile si legge con `responsibility_get_pid_for_pid`, funzione non documentata di macOS cercata a run time con `dlsym`; se manca o fallisce, si applicano le regole successive come prima, senza errori. I padri si leggono dalle informazioni di processo BSD e gli identificatori di bundle del responsabile e dei padri dalle app in esecuzione di AppKit. La lettura delle informazioni di processo (responsabile, padre, identificatore di bundle) sta dietro un protocollo, sostituito nei test; i test coprono almeno: responsabile riconosciuto, helper con id di un'altra app ma responsabile Teams, responsabile assente o non riconosciuto con ricaduta su id proprio/prefisso/helper/padri, limite di 8 livelli e arresto a identificatore ≤ 1.

Il rilevamento scrive nel registro diagnostico di LARP (vedi Task "Registro diagnostico"), area `detection`, una riga ogni volta che un processo inizia o smette di usare il microfono: oggetto processo Core Audio, identificatore di processo, identificatore di bundle come riportato da Core Audio (o vuoto), processo responsabile con il suo identificatore di bundle, catena dei padri con identificatore di processo e di bundle di ogni livello e motivo dell'arresto della risalita, app di call riconosciuta o nessuna. I processi che usano il microfono sono conservati, con quanto letto su di essi, sulla coda privata del rilevamento, così che la riga di stop riporti gli stessi dettagli dell'avvio.

Tutto il resto resta com'è e deve continuare a funzionare: rilevamento tramite listener (mai polling), app già al microfono riportate come avviate all'inizio, avvii/arresti simultanei in ordine alfabetico di nome, proposte, registrazioni, permessi, avvisi, scorciatoie e livelli.

## Code notes
Commit: 09822d2c2cd4d67434f3e6f8e5dbb2030694288a

- `Sources/LARP/Capture/CoreAudioCallAppMicSource.swift`: `refresh()` sulla coda seriale `larp.capture.coreaudio-mic`; calcola `Set<CallApp>` e fa diff con `activeApps`, emettendo `.started`/`.stopped` ordinati per nome. Oggi non tiene nulla per processo: serve uno stato `[AudioObjectID: …]` sulla coda per le righe di start/stop.
- `Sources/LARP/Capture/CoreAudioProcesses.swift`: `callApp(of:)`, `parentPID(of:)` (`proc_pidinfo(PROC_PIDTBSDINFO).pbi_ppid`), `bundleIdentifier(of:)` (vuoto dà `""`), `pid(of:)`, `processObject(forPID:)` (duplicato in `CoreAudioSystemDriver.processObject(forPID:)`). Enum statico con syscall dirette, non testabile: va portato dietro il protocollo. Attenzione: `guard parent > 1 else return nil` ferma sia su launchd sia su lookup fallito (il log deve distinguere il motivo); il pid proprio non è mai risolto via `NSRunningApplication`.
- `Sources/LARP/Capture/KnownCallApps.swift`: `KnownCallApps.all`, `app(forBundleIdentifier:in:)`, `CallApp.helperBundleIdentifiers`, regola prefisso `hasPrefix(id + ".")`; riusare per il match del responsabile.
- `CallAppMicSource.swift` (`CallAppMicEvent`) e `Recorder.handle(_:)` non dovrebbero cambiare.
- Test: `Tests/LARPTests/RecorderTests.swift` (`KnownCallAppsTests`, `FakeMicSource`).
- `Config/LARP.entitlements`: sandbox disattivata, `dlsym` possibile.
- Tenere coerenti gli id Teams con `TeamsInterface.bundleIdentifier` in `Sources/LARP/Teams/AccessibilityTeamsReader.swift`.
- Pid, bundle id e percorsi si possono loggare.
