---
refs:
  - playback
  - requirements/ui#playback
  - user.PLAY
  - user.PAUSE
  - user.SEEK
  - user.SELECT_SENTENCE
---
# Barra di riproduzione

Ridisegna i controlli di riproduzione come barra scura in fondo alla pagina di una call. La schermata della Style Guide (05 Meeting, barra in basso) è allegata a questo Task.

## Cosa deve valere alla fine

- La barra è ink, raggio 18, alta 64 px, a tutta larghezza sotto le due colonne della pagina: pulsante tondo lime 48 px play/pausa con glifo ink, il tempo raggiunto in JetBrains Mono bianco, la timeline e la lunghezza dell'audio in JetBrains Mono `#A3A69B`.
- La timeline ha un segmento per ogni riga della trascrizione al suo tempo, del colore del suo parlante, raggio 4, 2 px di spazio; le parti già ascoltate a colore pieno, il resto al 45 %; una barretta bianca di 2 px segna il tempo raggiunto. Clic o trascinamento sulla timeline spostano la posizione (`user.SEEK`): in riproduzione si prosegue dal nuovo tempo, in pausa tempo e riga evidenziata si spostano, da fermo si ignora; il tempo resta tra 0 e la lunghezza dell'audio.
- `user.PLAY` parte dall'inizio da fermo o dal tempo raggiunto in pausa, solo se la call ha audio; `user.PAUSE` mantiene il tempo raggiunto e la riga resta evidenziata; `user.SELECT_SENTENCE` (clic su una riga) riproduce dall'inizio della riga. Tempo e riga corrente si aggiornano ogni 100 ms.
- L'audio si carica solo quando la call non è più in registrazione; tracce mancanti, vuote o illeggibili si saltano. Senza alcuna traccia leggibile la barra mostra "Audio non disponibile" in `#A3A69B` al posto della timeline, con il pulsante disabilitato.
- Il resto del comportamento della riproduzione non cambia.

## Code notes
Commit: 58d947126f08b8c7e4128d08782a627080bde977
- `Sources/LARP/Playback/PlaybackControlsView.swift` `PlaybackControlsView` (`Slider` con stato di scrub): da sostituire con la timeline a segmenti.
- `Sources/LARP/Playback/PlaybackController.swift` `PlaybackController` (`show`, `setTimeline`, `seek`, `play(fromSentenceStart:)`, tick).
- `Sources/LARP/Playback/TranscriptTimeline.swift` `TranscriptTimeline`, `LineTiming`: riusabili per i segmenti della timeline.
- `Sources/LARP/Archive/CallDetailView.swift` `show()`/`updateTimeline()` collega la riproduzione alla pagina.
- Colori dei parlanti: mappatura stabile da `Participant.number`, `.me` ink, dallo strato visivo condiviso.
- Test in `PlaybackControllerTests.swift`; i riferimenti agli eventi del Model restano nei commenti.
