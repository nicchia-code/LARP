---
created: 2026-10-27T13:14:04.645Z
updated: 2026-10-28T19:35:58.002Z
summary: Rifinitura opzionale della trascrizione con omp. La verifica dello stato di omp ha un controller dedicato, condiviso con la sintesi, e la rifinitura ha solo Off e On. Ogni riga di Altri va a un partecipante.
tasks:
  - f6s57366
  - h37ekdg7
  - ow6l292u
  - vjcr36fd
  - o2lael0x
  - 14hjax3e
  - 5lotgio5
  - zkn6b1e7
  - 7d4rtdgf
  - d09h4lbq
---
# Rifinitura del testo con omp e stato di omp condiviso

La separazione assegna ogni riga non riconosciuta al partecipante della riga riconosciuta più vicina nel tempo, con Partecipante 1 di ripiego se nessuna riga è riconosciuta. L'etichetta Altri non viene più inviata a omp né accettata nella risposta.

La verifica di omp (installato, configurato, pronto) non sta più dentro la rifinitura: ha un controller dedicato, collegato in LARPApp.swift, che vale sia per la rifinitura del testo sia per la sintesi delle call. omp viene cercato solo mentre almeno una delle due è accesa. Nelle impostazioni lo stato («Verifica in corso…», «omp pronto», «omp non trovato») compare una sola volta, sotto i due interruttori.

La rifinitura si riduce a due stati: Off, in cui nessuna call viene rifinita, e On, in cui le nuove call vengono rifinite da sole dopo la separazione dei partecipanti. Dal codice sono stati tolti gli stati «Checking», «Assistant ready» e «Assistant missing» della rifinitura, e le transizioni di apertura delle impostazioni e di avvio dell'app che appartenevano a quel flusso.
