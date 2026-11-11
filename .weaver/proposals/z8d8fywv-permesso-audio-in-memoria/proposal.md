---
status: approved
kind: resolution
created: 2026-11-11T16:55:47.622Z
job: keaq1hyl
drifts:
- drift: f7gd2bj6
  decision: fix-code
  option: 1
---
# Permesso audio in memoria

- D1 Registrazione automatica senza chiedere il permesso audio: si corregge il codice. La registrazione automatica parte solo se il microfono è concesso e, in questo avvio dell'app, un tap dell'audio di sistema è già riuscito; altrimenti compare la proposta. Nessuna API privata e nessuna richiesta di macOS al rilevamento di una call.
