---
technical: false
refs:
  - system-audio
  - macos.AUDIO_DEVICES_CHANGED
  - requirements/tech#system-audio
  - requirements/ui#system-audio/Lost
---
# Audio di sistema segue l'uscita

Durante una registrazione la cattura dell'audio di sistema (Machine `system-audio`: Not captured, Captured, Lost) segue ogni cambio dell'uscita audio del Mac e della sua frequenza di campionamento, così la traccia dell'audio di sistema è sempre salvata alla velocità a cui è stata ascoltata. Oggi `SystemAudioTap.startIO` (Sources/LARP/Recording/SystemAudioTap.swift:105-114) legge `kAudioTapPropertyFormat` una sola volta all'avvio ed etichetta ogni buffer dell'I/O proc con quel formato (:117-123); il dispositivo aggregato resta legato all'uscita dell'avvio (:84-102) e nessuno ascolta i cambi. Quando la frequenza scende a metà chiamata (cuffie Bluetooth in modalità chiamata 16–24 kHz, cambio di uscita) i buffer sono etichettati male, `BufferConverter` (Sources/LARP/Recording/BufferConverter.swift:20-27) sottocampiona troppo e `TrackPipeline` (Sources/LARP/Recording/TrackPipeline.swift:85-106) riempie di silenzio: si sentono tratti 2–3 volte più veloci. Le chiamate già registrate restano come sono.

## Rilevamento di macos.AUDIO_DEVICES_CHANGED
Per l'audio di sistema `macos.AUDIO_DEVICES_CHANGED` è uno qualsiasi di: cambio del dispositivo di uscita predefinito (`kAudioHardwarePropertyDefaultOutputDevice`), cambio di `kAudioDevicePropertyNominalSampleRate` del dispositivo aggregato o del suo sotto-dispositivo di uscita, cambio di `kAudioTapPropertyFormat` del tap, oppure scomparsa del sotto-dispositivo di uscita dell'aggregato. Si osservano con property listener di Core Audio registrati in `SystemAudioTap`, mai con polling, e si gestiscono fuori dal thread di I/O di Core Audio (rimossi all'arresto della registrazione).

## Captured → Captured
A ogni evento: I/O proc fermato, dispositivo aggregato ricostruito sull'uscita predefinita corrente, formato del tap riletto, cattura ripartita. Ogni buffer porta il formato in vigore quando è stato catturato, mai uno letto a un avvio precedente; la conversione a 16 kHz mono in `BufferConverter` si ricostruisce ogni volta che quel formato cambia. La registrazione prosegue senza buchi più lunghi del tempo di ripartenza. Tenere conto che `CallAudioCapture` (Sources/LARP/Recording/CallAudioCapture.swift:70, :89) avvia il tap prima del microfono, che può mettere le cuffie Bluetooth in modalità chiamata subito dopo la lettura del formato: quel cambio deve essere seguito come qualsiasi altro.

## Captured → Lost
Se la cattura non riesce a ripartire: la registrazione prosegue con il solo microfono; la traccia dell'audio di sistema viene riempita di silenzio fino al tempo trascorso della registrazione, come già avviene per il microfono in `TrackPipeline`; `EchoRemover` (Sources/LARP/Recording/EchoRemover.swift, riferimento di sistema a :99) non riceve riferimento: il microfono viene salvato così come catturato, senza avviso di cancellazione dell'eco. L'utente viene avvisato (vedi pannello sotto).

## Lost
Ogni successivo `macos.AUDIO_DEVICES_CHANGED` ritenta l'avvio. Se riesce → Captured: gli altri partecipanti tornano registrati, il pannello scompare, `EchoRemover` viene resettato (:48-60) e la rimozione dell'eco riprende come all'inizio di una registrazione. Se fallisce ancora → resta Lost, la registrazione prosegue come prima. `recorder.RECORDING_STOPPED` da Captured o Lost → Not captured, e il pannello scompare.

## Pannello
Un piccolo pannello sotto l'icona della barra dei menu, che non ruba il focus, dice "Audio di sistema non disponibile: la registrazione prosegue senza gli altri partecipanti."; resta finché l'audio di sistema è perso e scompare quando torna o la registrazione finisce. Va realizzato sullo stesso modello del pannello del microfono perso: `MicrophoneLostPanelController` / `MicrophoneLostPresenting` in Sources/LARP/Capture/RecorderPresenters.swift (messaggio a :169), mostrato e nascosto da `Recorder` (Sources/LARP/Capture/Recorder.swift:164-173, :234) sugli eventi di `AudioCapturing.swift:68`; servono eventi analoghi per l'audio di sistema perso/ripristinato. Se anche il microfono è perso, i due pannelli sono impilati, ciascuno appare e scompare per conto proprio.

## Verifica
Test automatico con dispositivi finti che cambiano frequenza di campionamento a metà registrazione (accanto a Tests/LARPTests/BufferConverterTests.swift) che verifica durata e velocità della traccia di sistema e il passaggio Lost/Captured, più prova su un Mac reale con cuffie Bluetooth.
