---
column: todo
technical: false
refs:
  - call/Recording
  - macos.APP_LAUNCHED
  - requirements/tech#call
  - requirements/rules#call
  - requirements/quality#call/Recording
drift: null
proposal: dlpwzchv
agent: false
created: 2026-10-27T10:07:36.916Z
---
# Registrazione live

Realizzare lo stato **Recording** della macchina `call`: salvare l'audio della call e trascriverlo in diretta in background, e recuperare le call interrotte da una chiusura dell'app o da uno spegnimento del Mac.

Comportamento, come lo dice il Model:
- Una call nasce quando il `recorder` emette `RECORDING_STARTED`. Il microfono e l'audio di sistema vengono salvati di continuo come due tracce separate, così ciò che è stato registrato sopravvive se l'app si chiude.
- Se la lingua scelta nelle impostazioni è pronta all'avvio, entrambe le tracce vengono trascritte in diretta in background: il microfono come "Io" (Me), l'audio di sistema come "Altri" (Others). Durante la call non si mostra nulla della trascrizione (decisione dello sviluppatore: nessuna vista in diretta). Una lingua che diventa pronta a registrazione iniziata non avvia la diretta a metà.
- Quando il `recorder` emette `RECORDING_STOPPED`: se tutta la registrazione è stata trascritta in diretta → **Separating participants**; se una parte non è stata trascritta in diretta e la lingua è pronta → **Transcribing**; se la lingua non è pronta → **Awaiting language**.
- All'avvio dell'app (`macos.APP_LAUNCHED`), una call rimasta in **Recording** (app chiusa o Mac spento durante la registrazione) viene chiusa all'ultimo audio salvato, prima di qualsiasi altra cosa; se la lingua è pronta passa a **Transcribing** e viene ritrascritta dal suo audio, altrimenti passa a **Awaiting language**.

Come costruirlo:
- Microfono catturato con `AVAudioEngine` sul dispositivo di input predefinito; audio di sistema con un Core Audio process tap (`CATapDescription` su tutti i processi tranne LARP, `AudioHardwareCreateProcessTap`, aggregate device), che richiede solo il permesso di registrazione dell'audio di sistema e non quello di registrazione schermo.
- File `~/Library/Application Support/LARP/Recordings/<id call>/mic.caf` e `system.caf`, AAC mono a circa 32 kbps ciascuno, scritti a blocchi; l'audio va su disco almeno ogni 5 secondi, così un crash o uno spegnimento perde al massimo gli ultimi 5 secondi, e un file interrotto resta leggibile fino all'ultimo blocco scritto.
- Trascrizione con `SpeechAnalyzer` e un `SpeechTranscriber` per traccia, configurato con la lingua scelta (`it-IT` o `en-US`), risultati volatili e finali con gli intervalli di tempo; si salvano solo i risultati finali come righe (parlante, inizio, fine relativi all'inizio della call, testo). L'audio è convertito in `SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith:)`.
- La trascrizione gira fuori dal main actor e non deve mai bloccare la cattura: l'audio si scrive prima su disco, poi si passa all'analizzatore. Su un Mac M1 una call di un'ora con trascrizione in diretta di entrambe le tracce non deve perdere audio.
- La trascrizione di una call è l'insieme delle righe delle due tracce ordinate per tempo di inizio; la trascrizione da file (Task "Trascrizione da file") produce lo stesso tipo di righe.
- Test con Swift Testing per la scelta dello stato a fine registrazione e per il recupero all'avvio.
