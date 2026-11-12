---
technical: true
refs:
  - requirements/data#General
  - requirements/quality#General
  - requirements/tech#General
  - requirements/tech#capture
---
# Registro diagnostico

LARP tiene un registro diagnostico proprio, sempre attivo e senza interruttore, per capire a posteriori cosa è successo durante una chiamata. Il registro di macOS resta com'è: il file si aggiunge, non lo sostituisce.

Quando il Task è finito:

- Il registro sta in `~/Library/Logs/LARP/`, creata se manca, con un file di testo UTF-8 per giorno, `LARP-<yyyy-MM-dd>.log`. Ogni riga è un evento: data e ora locali in ISO 8601 con millisecondi, area (`detection`, `teams`, `capture`) e messaggio, separati da spazi. Ogni riga arriva su disco prima che sia scritta la successiva, così un crash o un Mac bloccato non perde le righe già scritte. Le righe sono scritte da una coda seriale privata; un errore di scrittura è ignorato e non tocca mai una registrazione.
- I file più vecchi di 30 giorni sono eliminati all'avvio e una volta al giorno mentre l'app è aperta.
- Il registro non contiene mai audio, testo delle trascrizioni, nomi di persone, titoli o altri testi letti da Teams o dal calendario: solo identificativi di processi e app, durate, conteggi, formati e motivi.
- Area `capture`: le righe che la cattura scrive oggi nel registro di macOS (formati a ogni avvio e riavvio di audio di sistema e microfono, secondi scritti, silenzio aggiunto e lunghezza della registrazione per traccia alla fine, buffer scartati e perché) sono scritte anche nel file, insieme al motivo di ogni riavvio del microfono (microfono da usare cambiato, formato cambiato, microfono sparito, microfono scelto dall'utente) e a ogni nuovo eliminatore dell'eco creato perché è cambiata solo l'uscita; al motivo di ogni riavvio dell'audio di sistema (quale valore della sua firma è cambiato, o quanti secondi senza audio quando si è fermato); a ogni perdita e a ogni ritorno del microfono e dell'audio di sistema. Le righe del registro di macOS restano come sono. Nulla è scritto da un thread audio.
- Il registro offre alle altre parti dell'app un modo unico per scrivere una riga di un'area; il rilevamento delle app di call (area `detection`) e la lettura di Teams (area `teams`) lo usano nei loro Task.
- Il README spiega dove si trova il registro (anche visibile nell'app Console), cosa scrive ogni area, e come avviare lo script di verifica di Teams e quale permesso serve al Terminale.

Il motivo dei riavvii del microfono va scritto anche dopo che il microfono passerà alla cattura solo ingresso con Core Audio (Task del Microfono): i motivi elencati restano gli stessi.

## Code notes

Commit: 09822d2c2cd4d67434f3e6f8e5dbb2030694288a

- Unico helper di log oggi: `Sources/LARP/Recording/CaptureLog.swift` (`CaptureLog`, `BufferDrops`, `TrackStats`), `Logger(subsystem: "com.larp.LARP", category: "capture")` a livello `.info`; `systemAudioStarted`, `microphoneStarted`, `trackStopped`. `TrackPipeline` riusa `CaptureLog.logger`. Il sottosistema `"com.larp.LARP"` è scritto a mano in 16 file: una costante condivisa aiuta.
- Convenzione: `private static let logger` per tipo, interpolazioni `privacy: .public`. Nessun test controlla l'output di `Logger`.
- Riavvii microfono: `Sources/LARP/Recording/MicrophoneCapture.swift` `restart(_:)` con `Trigger` (`.configurationChange`, `.devicesChanged`, `.choice`); `restart` gira sotto `lock`: scrivere dopo il lock, come fa `events`.
- Audio di sistema: `Sources/LARP/Recording/SystemAudioTap.swift` (`defaultStallTimeout = 2`, `checkStall`, `restart`, `heartbeat.secondsSinceLast()` per i secondi senza audio); `Sources/LARP/Recording/CoreAudioSystemDriver.swift` `CoreAudioSystemCapture.propertiesChanged` confronta `Signature`: per il motivo serve sapere quale campo differisce. `devicesChanged` unisce le raffiche tramite `changePending`: scrivere il motivo al trigger e l'esito in `restart()`.
- Fine registrazione: `Sources/LARP/Recording/CallAudioCapture.swift` `stop()` chiama `trackStopped`.
- L'I/O proc non deve scrivere, bloccare o allocare: continuare a contare con `BufferDrops`.
- Insidia: `.private` finisce comunque nel registro di macOS come `<private>`; i testi di Teams non vanno mai passati al logger.
- Il README oggi non ha alcuna sezione sui registri.
