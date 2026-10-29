---
technical: false
refs:
  - recorder/Recording
  - requirements/tech#recorder
  - requirements/quality#recorder/Recording
  - recorder/Idle/user.START_RECORDING
  - recorder/Proposing/user.ACCEPT_PROPOSAL
---
# Microfono alla velocità reale

Al termine, entrambe le tracce di una registrazione (microfono e audio di sistema) sono sempre salvate alla velocità a cui sono state sentite, qualunque cambio di microfono, di uscita audio o della loro frequenza di campionamento avvenga durante la registrazione: riascoltare una chiamata registrata non suona mai più veloce o più lento della chiamata stessa. Le chiamate già registrate restano come sono: nessuna riparazione.

## Microfono
Gli stati `Microphone on` / `Microphone lost` di `recorder/Recording` non cambiano: su `macos.AUDIO_DEVICES_CHANGED` il microfono riparte oppure è perso. Cambia come parte e riparte. All'avvio di una registrazione (`user.START_RECORDING` da Idle, `user.ACCEPT_PROPOSAL` da Proposing) e a ogni riavvio del microfono l'`AVAudioEngine` viene resettato (oppure se ne crea uno nuovo) prima di leggere il formato dell'input node, così il tap e la conversione a 16 kHz usano sempre la frequenza che il microfono fornisce davvero. Ogni buffer è convertito dal formato con cui è stato catturato, mai da un formato letto a un avvio precedente.

Dove: `Sources/LARP/Recording/MicrophoneCapture.swift` — lettura di `input.outputFormat(forBus: 0)` (righe ~100-111) sullo stesso engine senza reset; percorso di riavvio (~67-71, ~126-161) e microfono perso (~165-206). `BufferConverter.swift` (~20-27) ricostruisce il converter solo quando cambia il formato dichiarato: deve ricevere il formato reale di ogni buffer. `EchoRemover.swift` (~48-60 ricostruisce i converter al reset, ~99 usa il formato di sistema come riferimento) deve restare coerente quando il formato di una delle due sorgenti cambia. `AACFileWriter.swift` continua a scrivere a 16 kHz; `TrackPipeline.swift` (riempimento di silenzio ~94-99, `gapTolerance` ~15) non deve mascherare tratti accelerati.

Se l'audio di sistema è catturato, oppure perso dopo un cambio di dispositivi, è seguito dalla Machine dell'audio di sistema, non da `recorder/Recording`: la logica di riavvio della cattura di sistema è oggetto di un'altra Task.

## Verifica
- Test automatico (in `Tests/LARPTests`, accanto a `BufferConverterTests.swift`): tramite dispositivi audio finti, registra un tono di frequenza nota sul microfono e sull'audio di sistema mentre ciascun dispositivo cambia frequenza durante la registrazione (per esempio da 48 kHz a 24 kHz e a 16 kHz, e ritorno). In ogni traccia salvata il tono mantiene la sua frequenza e la durata salvata corrisponde al tempo in cui è stato fornito, entrambe entro l'1%. Il lato audio di sistema del test dipende dalla logica di riavvio della cattura di sistema (`SystemAudioTap`) introdotta dalla Task dell'audio di sistema: il dispositivo finto di sistema va esercitato attraverso quella logica.
- Su un Mac reale: durante una chiamata con cuffie Bluetooth che passano alla modalità chiamata, e cambiando l'uscita audio durante una registrazione, entrambe le tracce della chiamata registrata si riascoltano a velocità normale dall'inizio alla fine.
