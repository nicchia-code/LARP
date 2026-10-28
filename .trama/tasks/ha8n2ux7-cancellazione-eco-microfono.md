---
column: done
technical: false
refs:
  - recorder
  - macos.AUDIO_DEVICES_CHANGED
  - requirements/tech#recorder
  - requirements/ui#recorder/Recording
  - requirements/quality#recorder/Recording
drift: null
proposal: mdpdry2v
agent: false
created: 2026-10-27T16:29:21.246Z
finished: 2026-10-27T16:33:07.270Z
---
# Cancellazione eco microfono

Senza cuffie gli altoparlanti del Mac riproducono gli altri partecipanti e il microfono li riprende: oggi la traccia del microfono viene registrata senza alcuna cancellazione dell'eco, quindi gli altri finiscono sia nella traccia del microfono ("Io") sia in quella dell'audio di sistema ("Altri"). In riascolto le due tracce sommate fanno sentire gli altri due volte e nella trascrizione le loro frasi compaiono anche come righe "Io".

A lavoro finito:

- In `recorder/Recording` il suono degli altri partecipanti che il microfono riprende dagli altoparlanti viene tolto dal microfono, con o senza cuffie: il microfono tiene solo la voce dell'utente e gli altri si sentono e si trascrivono una volta sola, dall'audio di sistema.
- Il microfono è catturato con `AVAudioEngine` sul dispositivo di ingresso predefinito con `setVoiceProcessingEnabled(true)` sull'input node prima dell'avvio del motore, sempre, qualunque sia l'uscita audio (altoparlanti, casse esterne o cuffie): nessun rilevamento dell'uscita.
- L'abbassamento del volume delle altre app (compresa quella della chiamata) è al minimo: `voiceProcessingOtherAudioDuckingConfiguration` con `enableAdvancedDucking` attivo e `duckingLevel` `.min`.
- Il controllo automatico del guadagno del voice processing resta come lo imposta macOS (attivo).
- Il tap del microfono usa il formato letto dopo aver attivato il voice processing; qualunque frequenza di campionamento o numero di canali venga riportato è convertito nel formato di salvataggio 16 kHz mono.
- `user.START_RECORDING` e `user.ACCEPT_PROPOSAL` → Recording: quando il suono degli altri non si riesce a togliere dal microfono (attivazione del voice processing fallita), la registrazione parte comunque senza toglierlo e l'utente viene avvisato di usare le cuffie.
- Nuovo evento `macos.AUDIO_DEVICES_CHANGED` (il microfono o l'uscita audio del Mac è cambiato, per esempio cuffie collegate o scollegate), che corrisponde alla notifica `AVAudioEngineConfigurationChange` del motore durante una registrazione. `recorder/Recording` → Recording: la registrazione prosegue con il nuovo microfono o la nuova uscita e il suono degli altri viene di nuovo tolto dal microfono (il motore riparte con il voice processing riattivato); quando non è più possibile, la registrazione prosegue senza toglierlo e l'utente viene avvisato di nuovo.
- L'avviso è un piccolo pannello sotto l'icona nella barra dei menu che non prende il fuoco, con il testo "Cancellazione dell'eco non disponibile: usa le cuffie per non sentire gli altri due volte.", e sparisce da solo dopo 10 secondi.
- Senza cuffie, con un'app di chiamata che riproduce gli altri dagli altoparlanti integrati del Mac a volume normale, gli altri non si sentono nella traccia del microfono e non producono righe "Io". Va verificato su un Mac reale con gli altoparlanti, perché i test automatici non possono riprodurre dagli altoparlanti; in particolare va verificato che la cancellazione tolga anche l'audio riprodotto dalle altre app e che conviva con l'aggregate device del tap dell'audio di sistema. I test che toccano microfono o audio di sistema sono marcati `.requiresHardware`.

Fuori da questo lavoro: le chiamate già registrate restano come sono; l'allineamento dell'inizio delle due tracce (oggi ogni `TrackPipeline` fissa il proprio inizio sul primo buffer ricevuto) non cambia; l'unione delle righe e il riascolto non cambiano.

Dove sta oggi nel codice:

- `Sources/LARP/Recording/MicrophoneCapture.swift` — `MicrophoneCapture.installTapAndStart()` (tap sull'input node, nessun voice processing) e il riavvio su `.AVAudioEngineConfigurationChange` (`restartAfterConfigurationChange`).
- `Sources/LARP/Recording/BufferConverter.swift` — conversione al formato di salvataggio, ricostruisce l'`AVAudioConverter` quando cambia il formato.
- `Sources/LARP/Recording/CallAudioCapture.swift` — `start(into:sink:)`, avvia prima il tap di sistema e poi il microfono.
- `Sources/LARP/Recording/SystemAudioTap.swift` — tap di processo e aggregate device privato sull'uscita predefinita.
- `Sources/LARP/Capture/Recorder.swift` e `Sources/LARP/Capture/RecorderPresenters.swift` — macchina del registratore e presenter (il pannello della proposta `ProposalPanelController` è il modello per il nuovo pannello di avviso, sostituibile nei test come gli altri presenter).
