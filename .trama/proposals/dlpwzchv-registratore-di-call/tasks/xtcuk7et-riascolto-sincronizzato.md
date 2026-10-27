---
refs:
  - playback
  - user.PLAY
  - user.PAUSE
  - user.SELECT_SENTENCE
  - requirements/ui#playback
---
# Riascolto sincronizzato

Realizzare la macchina `playback`: ascoltare l'audio della call mostrata nella finestra dell'archivio con la trascrizione che segue (decisione dello sviluppatore: riascolto sincronizzato).

Comportamento, come lo dice il Model:
- **Stopped** (iniziale): nessun audio in riproduzione. Play → **Playing** dall'inizio della call. Clic su una frase → **Playing** dall'inizio di quella frase.
- **Playing**: l'audio della call suona e la frase che si sta ascoltando è evidenziata nella trascrizione. Pausa → **Paused**. Clic su una frase → salta all'inizio di quella frase. Fine dell'audio (`PLAYBACK_ENDED`) → **Stopped**. Selezione di un'altra call, chiusura della finestra o eliminazione della call in riproduzione → **Stopped**.
- **Paused**: audio fermo dov'era. Play → **Playing** da dove era in pausa. Clic su una frase → **Playing** dall'inizio della frase. Selezione di un'altra call, chiusura della finestra o eliminazione della call in pausa → **Stopped**.

Come costruirlo:
- Si riproducono insieme le due tracce `mic.caf` e `system.caf` della call (per esempio con `AVAudioEngine` e due player sincronizzati, o un mix), allineate al tempo delle righe di trascrizione.
- Controlli: pulsante play/pausa, tempo corrente e totale, barra di avanzamento trascinabile.
- Durante la riproduzione la riga in ascolto è evidenziata e resta visibile scorrendo la trascrizione.
- Funziona anche per le call non ancora trascritte (solo audio, senza frasi da cliccare).
- Test con Swift Testing della ricerca della riga corrente a partire dal tempo.
