---
status: fixed
refs:
- requirements/tech#recorder
- requirements/rules#recorder
- auto-recording
origin: tadc4cvk
task: znxx3skh
option: 1
job: e5ko6tv6
created: 2026-11-11T16:24:35.964Z
decided: 2026-11-11T16:56:36.798Z
---
# Registrazione automatica senza chiedere il permesso audio

## What happens

Per decidere se registrare da sola, la registrazione automatica legge il permesso dell'audio di sistema **senza chiedere** tramite un controllo privato del database dei permessi di macOS, non documentato e mai provato su un Mac reale. Se il controllo non è raggiungibile, il permesso conta come non concesso e compare la proposta.

## What should happen

I Requirements dicono che il permesso dell'audio di sistema si verifica creando e distruggendo subito un tap di processo globale privato, e che la registrazione automatica richiede entrambi i permessi già concessi, letti **senza chiedere**. Il tap, la prima volta, fa comparire la richiesta di macOS: le due regole non si possono rispettare insieme con un controllo solo, e il Requirement non indica quale scelta di costruzione valga per la lettura senza richiesta.

## Fix options

### Ricordare in memoria un tap riuscito

La registrazione automatica parte solo se il microfono è concesso e, in questo avvio dell'app, un tap di sistema è già riuscito (per esempio accettando una proposta). Altrimenti compare la proposta. Nessuna richiesta a sorpresa e nessuna API privata; costo: la prima call dopo ogni avvio passa dalla proposta.

### Sondare il tap quando si accende l'interruttore

Accendendo la registrazione automatica (o all'avvio, se è già accesa) si fa il tap di prova: la richiesta di macOS compare in un momento scelto dall'utente e il risultato resta in memoria. Il rilevamento di una call non chiede mai nulla. Costo: la richiesta può comparire fuori dal contesto di una call.

## Where in the code

Sources/LARP/Capture/SystemRecordingPermissions.swift (lettura senza chiedere); Sources/LARP/Capture/Recorder.swift (registrazione automatica alla partenza di una call)
