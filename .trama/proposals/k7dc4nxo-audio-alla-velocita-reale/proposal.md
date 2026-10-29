---
status: approved
base:
  capture/recorder.md: 931755d3a2c5fc6b68c4b58b2f62f93d9bee3140ed52779e20f957e5cfc16bc9
  capture/system-audio.md: new
  capture/feature.md: 748330e96722630510e382f1f2228e943b8adfd7598566ecbdb5a790d4464cea
  library/playback.md: 6337ba1c6104100aaa8377ab8cc93af0cd22d7cc77b96b7fc2ace5c2690eaf43
  actors/macos.md: 116c09dda50f96d5dc8e3ab6dab780c01c2749da910031782181066414ff9b3b
  requirements/tech/stack.md: 9b67c4927d33577d03af97aeed73cacf1d4dfe22f7ed34492bb8089aa8062720
  requirements/ui/screens.md: 329b3eb81dda0ede91029fdfa4929f9de1f9eabd60938d68cec54a2eb853be3f
  requirements/quality/main.md: 04ac293019f35d9d7d71427021e00d2aa4934d28cc398d0a75d90dad19e8061f
delete: []
request: 2026-10-29T15-04-22
created: 2026-10-29T14:31:34.345Z
label: Velocità audio
---
# Audio alla velocità reale

La riproduzione di alcune chiamate risulta accelerata in modo apparentemente casuale. Dal codice la riproduzione legge i file correttamente; la causa più probabile è la registrazione: l'audio di sistema legge la frequenza di campionamento una sola volta all'avvio, e quando l'uscita cambia frequenza o dispositivo durante la chiamata (per esempio cuffie Bluetooth che passano al profilo chiamata a 16–24 kHz) i campioni restano etichettati con la vecchia frequenza e quel tratto viene salvato accelerato, a scatti intervallati da silenzi. Questa Proposal fa sì che entrambe le tracce restino sempre alla velocità reale e definisce cosa succede quando l'audio di sistema o l'uscita della riproduzione cambiano.

## Decisioni

- Entrambe le tracce (audio di sistema e microfono) seguono ogni cambio di dispositivo o di frequenza durante una registrazione e vengono salvate alla velocità reale.
- Se dopo un cambio di uscita l'audio di sistema non riparte, la registrazione continua col solo microfono, la traccia di sistema contiene silenzio, l'utente vede un avviso e ogni cambio successivo di dispositivo riprova.
- L'avviso è un pannellino persistente sotto l'icona della barra dei menu, "Audio di sistema non disponibile: la registrazione prosegue senza gli altri partecipanti.", visibile finché l'audio di sistema non torna o la registrazione finisce.
- Se mancano insieme microfono e audio di sistema, i due pannelli appaiono impilati, ognuno indipendente.
- Le chiamate già registrate restano come sono: nessun tentativo di recupero.
- Durante la riproduzione, un cambio di uscita fa proseguire la riproduzione dallo stesso punto sulla nuova uscita; se non riesce a ripartire, va in pausa nel punto in cui era.
- Verifica: un test automatico con un dispositivo finto che cambia frequenza a metà registrazione, più una prova su un Mac reale con cuffie Bluetooth durante una chiamata.

## Assunzioni da verificare

- Il test automatico usa un tono a frequenza nota: nell'audio salvato la durata e la frequenza del tono restano entro l'1% di quelle reali.
- Quando la riproduzione va in pausa perché la nuova uscita non riparte, non viene mostrato alcun avviso.
- Una registrazione avviata a mano senza audio di sistema non prova ad avviarlo ai cambi di dispositivo successivi, come oggi.
- Il cambio della frequenza di campionamento dell'uscita, anche senza cambio di dispositivo, conta come cambio dei dispositivi audio.
