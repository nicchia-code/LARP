---
created: 2026-10-28T17:44:26.948Z
updated: 2026-10-28T19:35:58.059Z
summary: Cancellare una call mentre trascrizione, separazione, rifinitura o sintesi lavorano non manda più in crash l'app né i test; nuovi test coprono i quattro casi.
tasks:
  - 7mh65ax8
  - sn18ew7p
---
# Cancellazione sicura durante i lavori

Il crash intermittente dei test nella CI era causato da un lavoro in background che leggeva l'archivio dopo la cancellazione della call (o dopo la fine del contenitore dei dati). Il ciclo di vita della call ora conserva il contenitore dei dati e i lavori cancellati scartano esito ed errore senza toccare più la call, le sue righe, i suoi partecipanti o la sua sintesi. Quattro test deterministici cancellano una call durante ciascun lavoro (trascrizione, separazione, rifinitura, sintesi), senza attese a tempo fisso. Nel caso della sintesi il test verifica anche che il processo omp venga terminato e che nulla venga salvato.
