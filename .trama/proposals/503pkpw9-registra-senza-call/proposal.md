---
status: approved
base:
  capture/recorder.md: 681ae029eeb34638aa1d2f2fb96a3e6116f63732a8db5b41377428ca25229680
  requirements/data/storage.md: baa32d8d856b2e63b23719ec695f90f39858dedd370306865277af310c45332f
  requirements/quality/main.md: 251220e0f27b75fb2430d9385e86a8fe84d42145db80f3ea0e22a3510d3726c3
  requirements/rules/behaviour.md: b497791c961f475cdcb79539f7f1290a2ebecaa578d25bc54fcb49c412a17814
  requirements/tech/stack.md: 0253bd40ed43b386c80cce8cdb2a4f280cbb0a71323a080bb544fdf381c4b943
  requirements/ui/screens.md: e89fefe575542794bed065f11704aa355c2c9dbcda6b810457118476ba6a398c
delete: []
request: 2026-10-28T15-35-22
created: 2026-10-28T15:25:09.246Z
label: Registra senza call
---
# Registra senza call

La richiesta: "Registra" deve funzionare senza nessuna call e senza che un'altra app usi il microfono, accendendolo da sé. Il codice già accende il microfono da sé e non lega l'avvio manuale a nessuna call; restava però obbligatorio il permesso dell'audio di sistema, un microfono che non riparte dopo un cambio di dispositivi registrava silenzio senza avviso, e ogni registrazione si chiamava "Call del …".

## Decisioni

- "Registra" nel menu, con la proposta aperta, continua ad accettarla: la registrazione resta legata alla call app.
- Un avvio manuale da Idle richiede solo il permesso del microfono; registra anche l'audio di sistema quando è disponibile, altrimenti solo il microfono.
- Il ripiego sul solo microfono vale solo per l'avvio manuale, non per la proposta accettata.
- Il ripiego è segnalato da un pannello sotto l'icona che non ruba il focus, sparisce dopo 10 secondi e, se manca il permesso, ha un pulsante per Impostazioni di Sistema.
- In una registrazione con il solo microfono non compare l'avviso sulla cancellazione dell'eco.
- Se il microfono non riparte dopo un cambio di dispositivi, la registrazione prosegue (anche se resta senza nessuna traccia attiva), un pannello resta finché il microfono riprende o la registrazione finisce, e il microfono riprende al cambio di dispositivi successivo.
- Per il tempo senza microfono la traccia del microfono contiene silenzio.
- Le registrazioni senza call app si chiamano "Registrazione del …"; le call rilevate restano "Call del …".
- Le voci del microfono non vengono separate: tutto ciò che arriva dal microfono resta "Io".
- L'archivio non segna le registrazioni con il solo microfono.
- Nuovo requisito di qualità: verifica su un Mac reale dell'avvio manuale senza call.

## Assunzioni

- Mentre il microfono è perso, anche un cambio del microfono predefinito o dei dispositivi collegati conta come cambio di dispositivi audio, perché il microfono possa riprendere.
- Senza audio di sistema il file della traccia dell'audio di sistema viene comunque creato e resta vuoto, come fa già il codice.
- I testi dei pannelli sono quelli proposti nelle domande.
