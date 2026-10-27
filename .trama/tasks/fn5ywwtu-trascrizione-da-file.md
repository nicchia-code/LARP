---
column: todo
technical: false
refs:
  - call/Awaiting language
  - call/Transcribing
  - call.TRANSCRIPTION_COMPLETED
drift: null
proposal: dlpwzchv
agent: false
created: 2026-10-27T10:07:36.916Z
---
# Trascrizione da file

Realizzare gli stati **Awaiting language** e **Transcribing** della macchina `call`: trascrivere dall'audio salvato le call che non sono state trascritte in diretta.

Comportamento, come lo dice il Model:
- **Awaiting language**: l'audio è conservato ma non c'è ancora trascrizione, perché la lingua scelta non è installata sul Mac (decisione dello sviluppatore: si registra comunque e si trascrive appena la lingua è disponibile). Quando la macchina `transcription-language` emette `LANGUAGE_READY` → **Transcribing**.
- **Transcribing**: entrambe le tracce (`mic.caf` come "Io", `system.caf` come "Altri") vengono trascritte dall'audio salvato nella lingua scelta. Al termine si emette `TRANSCRIPTION_COMPLETED` → **Separating participants**. Se l'app si chiude durante la trascrizione, al riavvio (`macos.APP_LAUNCHED`) la trascrizione riparte dall'inizio, scartando le righe parziali.
- Rinomina ed eliminazione in questi stati seguono il Model (titolo nuovo; eliminazione che ferma la trascrizione e cancella audio e trascrizione parziale) e sono realizzate dal Task "Gestione call"; questo Task garantisce che una trascrizione in corso si fermi pulita quando la call viene eliminata.

Come costruirlo:
- `SpeechAnalyzer` con un `SpeechTranscriber` per traccia, alimentato dal file audio (`AVAudioFile`), stessa configurazione e stesso tipo di righe della trascrizione in diretta (parlante, inizio e fine relativi all'inizio della call, testo; solo risultati finali). La trascrizione della call è l'unione delle righe delle due tracce ordinate per tempo di inizio.
- La trascrizione gira fuori dal main actor; più call in attesa vengono trascritte una alla volta, in ordine di inizio.
- Test con Swift Testing delle transizioni e del riavvio dopo una chiusura durante la trascrizione.
