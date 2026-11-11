---
status: approved
kind: change
base:
  model/actors/time.md: 158f8799093e0e62666ce8a8ac1ee40e5ff6bea83959ad65fbd949dd60f0092d
  model/capture/system-audio.md: 6dd6b75dd31e993d85537f34df034c325d64ef593af29d5d34750a05a4152645
  requirements/data/capture.md: c5c47323cd3471440a45b233fc606af1b80c39f75dbf9682890ef278c3be5234
  requirements/rules/capture.md: d53b57e7e4f218bfc97e10fd1becd120de6c10bc044d345bc20d221545784733
  requirements/tech/capture.md: 2f4ce2ba4a4151e85bd198badbe7e660d683b99aea76e2f31efcc3573253a7e6
created: 2026-11-11T18:42:41.807Z
request: 2026-11-11T19-35-55
label: Audio di sistema
job: bu92u2by
---
# Audio di sistema a velocità reale

Segnalazione: alcune parti dell'audio sono velocizzate e l'audio di sistema (gli altri partecipanti) non viene preso correttamente.

Diagnosi sull'ultima registrazione (cuffie Sony WH-1000XM5 come uscita e microfono): la chiamata è durata 23,7 s, la traccia del microfono 23,0 s, quella dell'audio di sistema 12,3 s. Quando il microfono delle cuffie si apre, le cuffie passano in modalità chiamata e l'uscita scende da 44,1 kHz stereo a 16 kHz mono. La cattura legge il formato del tap una sola volta, prima che il dispositivo aggregato sia pronto, e continua a etichettare a 44,1 kHz l'audio che arriva a 16 kHz: ogni pezzo è circa 2,7 volte più veloce, e il riempimento dei buchi inserisce circa 0,9 s di silenzio ogni 1,5 s. La firma dei riavvii non confronta mai la frequenza reale con l'etichetta, quindi nessun riavvio corregge l'errore. Inoltre la cattura prende sempre il primo buffer dell'ingresso dell'aggregato, che in modalità chiamata può non essere il tap, e una traccia la cui sorgente smette di consegnare audio senza essere segnata persa resta più corta della registrazione.

Decisioni:
- Frequenza: l'audio di sistema è etichettato con il formato reale dello stream del tap nel dispositivo aggregato, letto dopo averlo avviato; la cattura riparte da zero quando quel formato cambia o differisce da quello usato.
- Stream: la cattura legge esplicitamente lo stream che appartiene al tap; se non si trova, la cattura non parte (o va persa) come quando il tap non si avvia.
- Tracce: ogni traccia copre tutta la registrazione, dal suo inizio allo stop, riempita di silenzio dove manca audio, anche quando la sorgente non era segnata persa.
- Audio che smette di arrivare: dopo 2 secondi senza audio di sistema la cattura riparte da zero sull'uscita attuale; se non riparte diventa persa, con l'avviso già previsto.
- Diagnostica: log locale a ogni avvio e riavvio (formato del tap e dello stream reale), allo stop (durata di ogni traccia, della registrazione, silenzio aggiunto) e conteggio dei buffer scartati.
- Registrazioni esistenti: nessuna azione, la correzione vale per le nuove.

Assunzioni dell'agente, da verificare:
- La traccia dell'audio di sistema di una registrazione avviata a mano, quando l'audio di sistema non è mai partito, resta vuota come oggi e non viene riempita di silenzio.
- Il riavvio dopo 2 secondi senza audio non avvisa l'utente, come un riavvio dopo un cambio di dispositivi; il silenzio digitale (niente in riproduzione) conta come audio che arriva.

## Already present

- `microphone/On/system-audio.LOST` — `Sources/LARP/Recording/SystemAudioTap.swift` (percorso `lost`) e `EchoRemover.suspendReference`/`resumeReference`
