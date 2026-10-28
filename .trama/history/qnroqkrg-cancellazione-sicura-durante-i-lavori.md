---
created: 2026-10-28T17:44:26.948Z
updated: 2026-10-28T17:44:26.948Z
summary: Cancellare una call mentre trascrizione, separazione o rifinitura lavorano non manda più in crash l'app né i test; nuovi test coprono i tre casi.
tasks:
  - 7mh65ax8
---
# Cancellazione sicura durante i lavori

Il crash intermittente dei test nella CI era causato da un lavoro in background che leggeva l'archivio dopo la cancellazione della call (o dopo la fine del contenitore dei dati). Il ciclo di vita della call ora conserva il contenitore dei dati e i lavori cancellati scartano esito ed errore senza toccare più la call, le sue righe o i suoi partecipanti. Tre test deterministici cancellano una call durante ciascun lavoro, senza attese a tempo fisso.
