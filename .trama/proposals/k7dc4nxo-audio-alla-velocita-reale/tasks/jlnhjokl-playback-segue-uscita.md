---
technical: false
refs:
  - playback/Playing
  - requirements/tech#playback
  - playback/Stopped/user.PLAY
  - playback/Stopped/user.SELECT_SENTENCE
  - playback/Paused/user.PLAY
  - playback/Paused/user.SELECT_SENTENCE
---
# Riproduzione segue l'uscita audio

Quando, durante la riproduzione di una chiamata, cambia l'uscita audio del Mac (cuffie collegate o scollegate, passaggio a Bluetooth, cambio di frequenza di campionamento), l'audio deve continuare dal punto raggiunto sulla nuova uscita, alla velocità a cui è stato registrato. Oggi `TrackPlayer` (Sources/LARP/Playback/TrackPlayer.swift) non osserva `AVAudioEngineConfigurationChange`: l'engine si ferma mentre l'interfaccia mostra ancora Playing.

Comportamento richiesto, in `TrackPlayer` e `PlaybackController` (Sources/LARP/Playback/PlaybackController.swift):

- Il player osserva `AVAudioEngineConfigurationChange` del proprio `AVAudioEngine`; per la riproduzione questo evento è `macos.AUDIO_DEVICES_CHANGED`. La sottoscrizione viene rimossa quando il player viene scaricato (`unload`, PlaybackController.swift:154-161).
- Alla notifica: l'engine viene fermato, ogni player node viene ricollegato al main mixer con il `processingFormat` del proprio file (come già avviene alla costruzione, TrackPlayer.swift:43), e l'engine riparte con il formato dell'uscita corrente.
- Se lo stato era Playing, la posizione raggiunta prima del cambio (calcolata come `currentTime`, dalla prima traccia, TrackPlayer.swift:49-56) va letta prima di fermare l'engine; l'audio di tutte le tracce viene poi riprogrammato da quella posizione e la riproduzione prosegue, restando in `playback/Playing`. Attenzione: `start(at:)` chiama `halt()` (TrackPlayer.swift:59, 110-113); la posizione non deve andare persa né azzerarsi.
- Se l'engine non riesce a ripartire, la riproduzione passa a `playback/Paused` alla posizione raggiunta, senza alcun avviso all'utente. Il successivo play (`user.PLAY`) riparte da quel punto avviando l'engine sull'uscita corrente in quel momento.
- In Paused o Stopped il cambio di uscita non cambia stato: i nodi vengono comunque ricollegati, così il play successivo usa l'uscita corrente. Ogni passaggio a Playing (`user.PLAY` da Stopped o da Paused, `user.SELECT_SENTENCE` da Stopped o da Paused) avvia l'engine sull'uscita corrente in quel momento e riproduce alla velocità a cui l'audio è stato registrato.
- L'evidenziazione della frase in ascolto nella trascrizione e i controlli (play/pausa, tempo corrente/totale, barra di avanzamento) continuano a riflettere la posizione reale dopo il cambio, come da `requirements/ui#playback`.

Le chiamate già registrate non vengono modificate.
