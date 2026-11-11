---
refs:
  - microphone
  - microphone-choice
  - requirements/rules#microphone
  - requirements/tech#microphone
  - user.CHOOSE_MICROPHONE
---
# Microfono scelto

L'utente sceglie quale microfono registrare, nelle Impostazioni (riga "Microfono" della sezione Registrazione) e nella finestra a comparsa.

## Cosa deve valere

- La scelta offre "Predefinito di sistema" (il default) e i dispositivi di ingresso collegati ora, più quello scelto, mostrato "<nome> (non collegato)", quando manca.
- **Predefinito di sistema**: si registra il microfono predefinito del Mac, seguito quando cambia. **Microfono scelto**: si registra il dispositivo scelto, riconosciuto dal suo identificatore univoco, quando è collegato; quando non lo è, al suo posto il predefinito. Il microfono scelto torna in uso da solo quando viene ricollegato (assunzione dell'agente).
- Ogni scelta diversa è salvata; scegliere di nuovo "Predefinito di sistema" quando già lo è non cambia nulla.
- Una scelta durante la registrazione cambia subito microfono, solo se il microfono da usare cambia: la cattura riparte su di esso come per un cambio di dispositivi, il vuoto è riempito di silenzio nella traccia e, mentre l'audio di sistema è catturato, un nuovo cancellatore d'eco impara il percorso da capo. Se riparte senza audio di sistema o senza cancellatore si registra com'è; senza cancellatore l'utente è avvisato per 10 secondi di usare le cuffie. Se non può partire, il microfono è perso e compare l'avviso duraturo che il microfono non è disponibile.
- Dallo stato perso, ogni cambio dei dispositivi collegati o del microfono da usare è un'occasione per ripartire: se riparte il vuoto è riempito di silenzio e l'avviso sparisce; se no non si dice nulla.
- Tutto il resto della cattura resta com'è: avvio dopo l'audio di sistema, niente elaborazione vocale di macOS, cancellatore AEC3 solo, nuovo motore a ogni avvio con il formato riportato in quel momento.
- Salvataggio: `settings.microphone` con l'identificatore univoco del dispositivo come lo riporta Core Audio e `settings.microphoneName` con il nome per quando non è collegato; assente vale "Predefinito di sistema".

## Code notes
Commit: 58d947126f08b8c7e4128d08782a627080bde977
- `Sources/LARP/Recording/MicrophoneEngine.swift` `AVMicrophoneEngine`: il dispositivo scelto si imposta come current device sull'audio unit dell'input node; frequenza zero o nessun canale = nessun microfono.
- `Sources/LARP/Recording/MicrophoneCapture.swift` `MicrophoneCapture`: listener sul dispositivo predefinito; aggiungere quello sulla lista dei dispositivi perché il microfono scelto ricollegato venga ripreso. I listener girano su una coda privata e vanno rimossi fuori dal lock del microfono; le notifiche di configurazione di un motore già sostituito si ignorano.
- `Sources/LARP/Recording/CallAudioCapture.swift`, `TrackPipeline.swift` `fillSilence` per il vuoto.
- Avvisi: `Sources/LARP/Capture/RecorderPresenters.swift` (`MenuBarPanel`, notice controllers). Riga nella finestra a comparsa: `Sources/LARP/App/MenuBarContent.swift`; impostazioni `Sources/LARP/Settings/SettingsView.swift`; chiavi `SettingsKey.swift`.
- Il motore sta dietro un protocollo con dispositivi finti nei test; i test di hardware hanno il tag `requiresHardware`.
- Convenzione: controller `@MainActor @Observable final class` con `static let shared`, `UserDefaults` iniettato.
