---
column: done
technical: true
refs:
  - requirements/tech#General
drift: null
proposal: 15u4f1ps
agent: false
created: 2026-10-28T19:23:51.370Z
finished: 2026-10-28T19:24:32.240Z
---
# README per la sintesi

Il README, in inglese, documenta che la rifinitura del testo e le sintesi delle call richiedono omp installato e configurato dall'utente, e che entrambe mandano attraverso omp solo il testo della trascrizione, mai l'audio. Le altre parti del README (pubblicazione di una release con un tag `vX.Y.Z`, installazione e apertura dell'app scaricata) restano come sono.

La sintesi è facoltativa e spenta di default («Sintesi con omp» nelle Impostazioni), indipendente dalla rifinitura: il README lo dice in una frase. L'app non ha servizi cloud, account o telemetria propri: rifinitura e sintesi passano per l'omp dell'utente, che raggiunge il provider di modelli configurato in omp.
