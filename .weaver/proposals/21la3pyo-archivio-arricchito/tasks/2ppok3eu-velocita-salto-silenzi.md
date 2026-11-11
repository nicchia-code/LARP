---
refs:
- playback
- playback-options
- requirements/ui#playback
- requirements/rules#playback
- requirements/tech#playback
- requirements/data#playback-options
- user.CHANGE_SPEED
- user.TURN_ON_SKIP_SILENCE
- user.TURN_OFF_SKIP_SILENCE
---
# Velocità e salto silenzi

Quando il lavoro è finito, la barra di riproduzione offre la velocità e "Salta i silenzi", come dicono `playback-options` e `playback`; entrambe le scelte valgono per ogni call e si ricordano tra le call e tra gli avvii.

## Velocità
- La velocità è una chip di 32 px con bordo `#3A3C36` e testo bianco in JetBrains Mono ("1,0×", "1,25×"…). Ogni clic (`user.CHANGE_SPEED`) passa alla successiva nell'ordine 1×, 1,25×, 1,5×, 2×, 0,75×, poi di nuovo 1×; la nuova velocità viene salvata e vale subito, anche per l'audio in riproduzione, e l'intonazione delle voci non cambia.
- Ogni tempo misurato dalla riproduzione (tempo raggiunto, riga corrente, lunghezza) resta nel tempo dell'audio, non dell'orologio, a ogni velocità.
- Salvata come numero tra 0.75, 1, 1.25, 1.5 e 2; predefinita 1; ogni altro valore si legge come 1.

## Salta i silenzi
- La chip "Salta i silenzi" ha contorno e testo lime quando è attiva, contorno `#3A3C36` e testo `#A3A69B` quando è spenta. `user.TURN_ON_SKIP_SILENCE` e `user.TURN_OFF_SKIP_SILENCE` salvano la scelta (predefinita spenta); l'app parte senza salto, a meno che il salto non sia stato lasciato attivo.
- Mentre si ascolta con il salto attivo, quando il tempo raggiunto è in un tratto senza righe più lungo di 2 secondi (dalla fine della riga prima all'inizio della successiva, o dall'inizio dell'audio, o fino alla sua fine), la riproduzione salta a 0,3 secondi prima dell'inizio della riga successiva, oppure finisce quando non ce n'è; il tempo raggiunto mostra il salto. Il controllo avviene al passo di aggiornamento della riproduzione (ogni 100 ms) ed è uno spostamento di posizione come gli altri, tenuto tra 0 e la lunghezza dell'audio.
- Tutto il resto della riproduzione resta com'è: tracce che partono insieme, tracce illeggibili saltate, "Audio non disponibile" senza audio.

## Code notes
Commit: 58d947126f08b8c7e4128d08782a627080bde977
- `Sources/LARP/Playback/PlaybackController.swift` `PlaybackController` (`show`, `setTimeline`, `seek`, `play(fromSentenceStart:)`, tick): il salto è un `seek` fatto al tick che trova il tempo in un silenzio da saltare.
- `Sources/LARP/Playback/TrackPlayer.swift` `TrackPlayer`, `EngineTrackPlayer`: inserire un `AVAudioUnitTimePitch` condiviso da tutte le tracce tra i player e il mixer; la velocità è il suo `rate`. Il tempo raggiunto si legge in campioni dei file della prima traccia leggibile, così resta nel tempo dell'audio. Un cambio di configurazione riconnette ogni traccia e riparte dal tempo raggiunto: il time-pitch va riconnesso anch'esso.
- `Sources/LARP/Playback/TranscriptTimeline.swift` `TranscriptTimeline`, `LineTiming`: riusare per trovare i silenzi.
- Barra: `Sources/LARP/Playback/PlaybackControlsView.swift`.
- Impostazioni: chiavi in `Sources/LARP/Settings/SettingsKey.swift` (`playback.speed`, `playback.skipSilence`); `UserDefaults` iniettato, test con suite isolate (`makeDefaults()`), suite `.serialized`.
- Il player è dietro un protocollo e l'intervallo di aggiornamento è un parametro: testare in `PlaybackControllerTests.swift` con un player finto. Commenti con gli eventi del Model.
