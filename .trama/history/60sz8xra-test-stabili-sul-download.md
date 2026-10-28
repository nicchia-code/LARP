---
created: 2026-10-27T18:19:52.022Z
updated: 2026-10-27T18:19:52.022Z
summary: I test aspettano l'effetto che controllano (la chiamata registrata sul fake, il segnale dell'agente) e non uno stato intermedio o un tempo fisso, così passano anche su un runner lento.
tasks:
  - lj6rf32m
---
# Test stabili sul download

I test del download del modello di lingua attendono che l'installazione sia davvero partita prima di controllare le chiamate registrate. Le attese di durata fissa negli altri test di `Tests/LARPTests/` sono sostituite dall'attesa dell'effetto controllato. Il codice dell'app non cambia.
