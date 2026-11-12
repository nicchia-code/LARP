---
technical: false
refs:
  - microphone
  - requirements/rules#microphone
  - requirements/tech#microphone
  - specs#frameworks
---

# Microfono solo ingresso

La cattura del microfono durante una registrazione avviene direttamente dal dispositivo di ingresso con Core Audio, solo in ingresso: un'unità audio `kAudioUnitSubType_HALOutput` con ingresso abilitato e uscita disabilitata, con dispositivo corrente impostato sul microfono da usare (il dispositivo di ingresso scelto, se collegato e riconosciuto dal suo identificativo unico, altrimenti quello predefinito; con "Predefinito di sistema" sempre quello predefinito), avviata a ogni avvio e riavvio. `AVAudioEngine` non si usa più per il microfono, perché il suo lato di uscita lo ferma a ogni cambio dell'uscita (per esempio quando gli AirPods passano in modalità chiamata appena si apre il microfono). L'elaborazione vocale di macOS non viene mai attivata.

A ogni avvio il formato si legge dal lato di ingresso del dispositivo; frequenza zero o nessun canale significa che non c'è microfono. La richiamata di ingresso rende in un buffer preparato in anticipo, lo copia e ritorna: niente lock, allocazioni o log sul thread audio. Ogni buffer mantiene il formato di cattura e il tempo di sistema del suo ultimo frame.

I cambiamenti si seguono con listener Core Audio su una coda privata, rimossi fuori dal lock del microfono:
- dispositivo di ingresso predefinito ed elenco dei dispositivi (così il dispositivo scelto viene ripreso quando lo si ricollega);
- frequenza, formato di stream e vitalità del dispositivo in uso: riavviano la cattura;
- uscita predefinita e sua frequenza: creano solo un nuovo cancellatore d'eco, senza riaprire il microfono e senza buchi nella traccia.

Il microfono si riapre solo se cambia il microfono da usare, se cambia il suo formato o se sparisce; una nuova scelta dell'utente durante la registrazione riavvia la cattura come un cambio di dispositivi (solo se il microfono da usare cambia). Un buco dovuto a un riavvio vero è riempito di silenzio nella traccia.

Un nuovo cancellatore d'eco (AEC3 di WebRTC, da solo, modalità mobile spenta, impara il percorso d'eco da zero) si crea a ogni avvio e riavvio del microfono, a ogni cambio dell'uscita predefinita o del suo formato mentre il microfono prosegue, e a ogni ritorno dell'audio di sistema; si scarta mentre l'audio di sistema è perso. Senza cancellatore il microfono va alla traccia così com'è. Quando cambia solo l'uscita: se il cancellatore si può creare, l'avviso sull'eco ancora visibile scompare; se non si può, l'utente viene avvisato per 10 secondi di usare le cuffie. Se il riavvio non riesce il microfono è perso: avviso persistente sotto l'icona della barra dei menu che il microfono non è disponibile e la registrazione prosegue senza la voce dell'utente; ogni successivo cambio di dispositivi o di microfono scelto è un'occasione per ripartire, e al ritorno l'avviso scompare. Tutti gli altri comportamenti (avvio dopo l'audio di sistema, fallimento all'avvio, perdita e ritorno dell'audio di sistema, fine registrazione) restano quelli del Model.

La nuova cattura deve continuare a scrivere nel registro diagnostico (Task "Registro diagnostico", area `capture`) il formato catturato a ogni avvio e riavvio, il motivo di ogni riavvio (microfono da usare cambiato, formato del microfono cambiato, microfono sparito, microfono scelto dall'utente), ogni nuovo cancellatore creato perché è cambiata solo l'uscita, e ogni perdita e ritorno del microfono; mai dal thread audio, solo dalle code private. Le righe di `os.Logger` restano.

L'unità di ingresso e i suoi listener stanno dietro un protocollo, sostituito nei test da dispositivi finti.

## Code notes
Commit: 09822d2c2cd4d67434f3e6f8e5dbb2030694288a

- `Sources/LARP/Recording/MicrophoneCapture.swift` (~136-217): `installTapAndStart`, `start(_:)`, `restart(_:)`, `Trigger` (`.configurationChange`, `.devicesChanged`, `.choice`). Oggi `.configurationChange` (da `AVAudioEngineConfigurationChange`) riavvia sempre: va sostituito da trigger distinti (formato/vitalità del dispositivo → riavvio; uscita → solo `echoRemover.reset()`). `restart` gira sotto `lock`: log ed eventi dopo il lock, come fa `events`.
- `Sources/LARP/Recording/MicrophoneEngine.swift` (~58-73): `AVMicrophoneEngine.start` e l'observer; il motore è dietro un protocollo: sostituire l'implementazione con l'unità HAL, adeguando i finti.
- `Sources/LARP/Recording/EchoRemover.swift` (~60-90): `reset`, `suspendReference`, `resumeReference`; AEC3 solo sulla coda dell'echo remover.
- `Sources/LARP/Recording/CoreAudioSystemDriver.swift`: schemi riusabili per i listener (`Signature`, `propertiesChanged`, coda privata); commento ~177 sulle cuffie Bluetooth in modalità chiamata.
- `Sources/LARP/Recording/CaptureLog.swift`: `CaptureLog.microphoneStarted`; aggiungere qui i motivi di riavvio.
- Test: `Tests/LARPTests/CallAudioCaptureTests.swift`, `FakeAudioDevices.swift`, `TrackPipelineTests.swift`; aggiungere un caso "cambia solo l'uscita → nessun riavvio, reset del cancellatore".
