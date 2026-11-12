---
created: 2026-11-12T15:52:02.764Z
updated: 2026-11-12T15:56:27.035Z
summary: Un processo al microfono è attribuito prima all'app di call responsabile secondo macOS, con ricaduta sulle regole di bundle e processi padre e righe diagnostiche di rilevamento.
tasks:
- ud0aojaq
- xvslygrj
cleared:
  ud0aojaq:
    title: Rilevamento processo responsabile
    refs:
    - recorder
    - requirements/rules#recorder
    - requirements/tech#recorder
    technical: false
    proposal: i0s24q50
    label: Teams e diagnostica
    finished: 2026-11-12T15:35:11.237Z
    body: |-
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
  xvslygrj:
    title: 'Fix the code: Funzione del processo responsabile inesistente su macOS'
    refs:
    - requirements/tech#recorder
    - requirements/rules#recorder
    technical: true
    finished: 2026-11-12T15:54:48.260Z
    body: |-
      ## What happens

      Il rilevamento cerca a run time `responsibility_get_pid_for_pid`, il nome scritto nei Requisiti. Su questo Mac (macOS 27, verificato con `dlsym` da un processo di prova) quel simbolo **non esiste**: la ricerca fallisce sempre, il processo responsabile non viene mai letto e valgono solo le regole successive. Il simbolo che esiste e restituisce il responsabile è `responsibility_get_pid_responsible_for_pid`. Di conseguenza gli helper avviati dal sistema e gli helper con l'identificatore di un'altra app (Edge dentro Teams) non sono attribuiti correttamente.

      ## What should happen

      I Requisiti chiedono che un processo al microfono sia attribuito prima di tutto all'app responsabile, letta con una funzione di macOS cercata con `dlsym`. Con il nome scritto la funzione non può essere trovata, quindi il requisito non si può rispettare sulla piattaforma così com'è; il Task chiede inoltre che il Task sia verificabile con un responsabile reale.

      ## Chosen option

      ### Provare il nome scritto e poi quello reale

      La ricerca prova prima `responsibility_get_pid_for_pid` come da Requisiti e, se manca, `responsibility_get_pid_responsible_for_pid`. Il comportamento atteso (responsabile letto, ricaduta sulle regole successive se manca) si ottiene senza cambiare i Requisiti; costo: una riga in più e un nome nel codice che oggi non esiste.

      ## Where in the code

      Sources/LARP/Capture/ProcessInfoReading.swift, `SystemProcessInfoReader` (ricerca con `dlsym`)
---
# Rilevamento del processo responsabile

Il rilevamento legge il processo responsabile di ogni processo che usa il microfono e lo attribuisce all'app di call della tabella, poi ricade sull'identificatore del processo e sui padri. Ogni avvio o stop di un processo scrive una riga nell'area detection del registro diagnostico. La ricerca con dlsym prova prima il nome dei Requisiti e poi `responsibility_get_pid_responsible_for_pid`, quello che macOS esporta davvero, così il responsabile viene letto. Il Requisito nomina ancora solo `responsibility_get_pid_for_pid`: aggiornarlo è una decisione dello sviluppatore.
