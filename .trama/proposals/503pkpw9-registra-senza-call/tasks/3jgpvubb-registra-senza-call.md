---
technical: false
refs:
  - recorder
  - requirements/tech#recorder
  - requirements/ui#recorder/Recording
  - requirements/ui#recorder/Microphone lost
  - requirements/data#call
  - requirements/quality#recorder/Recording
---

# Registra senza call

Quando il Task è finito, nel Machine `recorder` valgono le regole seguenti.

**Avvio manuale da `Idle`.** `user.START_RECORDING` ("Registra" nel menu, `Sources/LARP/App/MenuBarContent.swift`) porta a `Recording` se c'è il permesso del microfono. Il permesso dell'audio di sistema non serve più. L'app accende il microfono da sé, che ci sia o no una call in corso e che un'altra app usi o no il microfono. La registrazione non è legata a nessuna call app e si ferma solo a mano (`user.STOP_RECORDING`). `macos.CALL_APP_MIC_STOPPED` non la chiude. Se manca il permesso del microfono, `user.START_RECORDING` lascia il recorder in `Idle`: non si registra nulla e l'utente viene avvisato che manca il permesso del microfono e di come concederlo in System Settings. Il permesso si controlla prima di ogni avvio con l'autorizzazione `AVAudioApplication`/`AVCaptureDevice`, mostrando il prompt di macOS se non è ancora stato deciso. Il permesso dell'audio di sistema si controlla dal risultato della creazione del tap.

**Audio di sistema all'avvio manuale.** L'audio di sistema si registra anche quando il suo permesso c'è e la sua cattura parte. Se il permesso manca, oppure se il process tap (`CATapDescription`) o l'aggregate device non partono, la registrazione non si ferma e si cattura solo il microfono. Oggi `CallAudioCapture.start` (`Sources/LARP/Recording/CallAudioCapture.swift`) avvia sempre `SystemAudioTap` e poi `MicrophoneCapture`, e a ogni errore lancia un'eccezione. Con quell'eccezione `Sources/LARP/Call/CallLifecycle+Recording.swift` cancella la call e mostra "Registrazione non partita". `SystemRecordingPermissions.missingPermission` (`Sources/LARP/Capture/SystemRecordingPermissions.swift`) chiede entrambi i permessi. Il ripiego sul solo microfono vale **solo** per l'avvio manuale da `Idle`. Con `user.ACCEPT_PROPOSAL` da `Proposing`, e quindi anche con "Registra" mentre la proposta è aperta (che resta un'accettazione, con la registrazione legata alla call app), servono ancora entrambi i permessi e la partenza di entrambe le catture, come oggi. Quando un avvio manuale registra solo il microfono:
- Sotto l'icona della menu bar compare un piccolo pannello che non ruba il focus, con il testo "Audio di sistema non disponibile: si registra solo il microfono.". Il pannello sparisce dopo 10 s.
- Se manca il permesso dell'audio di sistema, il pannello ha anche un pulsante "Apri Impostazioni di Sistema" che apre il pannello giusto di System Settings. Si possono riusare gli schemi di `RecorderPresenters.swift` / `EchoCancellationWarningPanelController`.
- `system.caf` viene comunque creato e resta vuoto.

**Avviso sull'eco.** Se si registra l'audio di sistema e non si può togliere dal microfono il suono degli altri partecipanti, la registrazione parte lo stesso senza toglierlo. In quel caso compare l'avviso "Cancellazione dell'eco non disponibile: usa le cuffie per non sentire gli altri due volte.". Questo avviso compare solo quando si registra l'audio di sistema e mai in una registrazione senza audio di sistema, anche se il voice processing non è disponibile. Restano invariati: `AVAudioEngine` sull'input predefinito, voice processing con ducking al minimo, 16 kHz mono, ripiego senza voice processing se fallisce, riavvio su `AVAudioEngineConfigurationChange`.

**Sub-States di `Recording`.** La vecchia self-transition `macos.AUDIO_DEVICES_CHANGED` → `Recording` è sostituita da due sub-States. `user.STOP_RECORDING` e `macos.CALL_APP_MIC_STOPPED` (quest'ultimo solo per una registrazione legata a una call app) valgono da entrambi.
- `Microphone on` (initial). Con `macos.AUDIO_DEVICES_CHANGED`, se il microfono riparte si resta in `Microphone on`: si prosegue con il nuovo microfono e la nuova uscita e l'eco viene di nuovo tolta. Se toglierla non è più possibile e si registra l'audio di sistema, si prosegue senza toglierla e l'utente viene avvisato di usare le cuffie. Se il microfono non può ripartire si va in `Microphone lost`.
- `Microphone lost`. Vi si entra quando il riavvio del microfono fallisce. La registrazione prosegue senza la voce dell'utente, con l'audio di sistema se viene registrato, e prosegue anche quando non si registra più nulla. La cattura dell'audio di sistema continua. Da quel momento la traccia microfono contiene silenzio. Sotto l'icona della menu bar c'è un piccolo pannello che non ruba il focus, con il testo "Microfono non disponibile: la registrazione prosegue senza la tua voce.". Il pannello resta finché il microfono è perso e sparisce quando il microfono torna o quando la registrazione finisce. Con `macos.AUDIO_DEVICES_CHANGED`, se il microfono riparte si torna a `Microphone on`: la voce viene di nuovo registrata, il pannello sparisce e l'eco viene tolta come all'avvio. Se non riparte si resta in `Microphone lost` e si prosegue come prima.

L'errore del riavvio del motore dopo `macos.AUDIO_DEVICES_CHANGED` non va mai ignorato. Oggi `MicrophoneCapture.restartAfterConfigurationChange` (`Sources/LARP/Recording/MicrophoneCapture.swift`) lo inghiotte con `(try? installTapAndStart()) ?? false`, e `CaptureError.noInputDevice` arriva da `installTapAndStartEngine`. Assunzione: mentre il microfono è perso, il motore fermo potrebbe non emettere più `AVAudioEngineConfigurationChange`. Per questo, in quello stato, contano come `macos.AUDIO_DEVICES_CHANGED` anche il cambio del dispositivo di input predefinito del Mac e il cambio dei dispositivi audio collegati. Ognuno di questi cambi riprova ad avviare il microfono.

**Dati della traccia microfono.** Mentre il microfono è perso, `mic.caf` viene riempito di silenzio per quel tempo. Questo vale anche quando la registrazione finisce prima che il microfono torni. Così `mic.caf` è lungo quanto la registrazione e i tempi delle sue righe restano allineati con `system.caf`. Oggi il riempimento dei vuoti in `Sources/LARP/Recording/TrackPipeline.swift` scatta solo all'arrivo di un buffer, quindi serve anche il riempimento alla fine.

**Fuori da questo Task.** Il titolo predefinito "Registrazione del …" delle registrazioni senza call app è coperto da un altro Task. Le voci del microfono non vengono separate. L'archivio non segna le registrazioni solo microfono.

**Test.** Vanno aggiornati o aggiunti i test in `Tests/` (`RecorderTests.swift`, `CallRecordingTests.swift`; `MicrophoneCaptureTests.swift` è `requiresHardware`) per i casi seguenti:
- avvio manuale con o senza permesso dell'audio di sistema;
- avvio manuale con il tap che fallisce;
- accettazione che richiede ancora entrambi i permessi;
- passaggio a `Microphone lost` e ritorno a `Microphone on`;
- silenzio in `mic.caf` anche fino alla fine della registrazione;
- `system.caf` vuoto;
- nessun avviso sull'eco senza audio di sistema.

Requisito di qualità: su un Mac reale, senza call in corso e senza altre app che usano il microfono, "Registra" da `Idle` registra la voce dell'utente nella traccia microfono, che viene trascritta come "Me". Questa verifica si fa su un Mac reale, perché i test automatici usano dispositivi audio finti.
