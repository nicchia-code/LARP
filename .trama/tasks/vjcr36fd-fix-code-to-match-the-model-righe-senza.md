---
column: done
technical: false
refs:
  - requirements/rules#call
  - call.PARTICIPANTS_SEPARATED
drift: 9el2cb25
proposal: null
agent: false
created: 2026-10-27T13:16:27.491Z
finished: 2026-10-27T13:19:22.487Z
---
# Fix code to match the Model: Righe senza partecipante

## What happens

Se la separazione per voce non riesce ad assegnare una riga di "Altri" a nessun partecipante, la riga resta "Altri". La rifinitura la manda a omp con l'etichetta **"Altri"**, che il testo dei Requirements non elenca, e permette di lasciarla "Altri" o di passarla a un partecipante.

## What should happen

Il Model dice che ogni riga di "Altri" va a un partecipante, e i Requirements dicono che a omp esce chi parla solo come **"Io"** o **"Partecipante <numero>"**. Il caso di una riga senza partecipante non è previsto, e la scelta cambia cosa esce dal Mac e cosa viene salvato.

## Chosen option

**Partecipante più vicino**

La separazione assegna ogni riga non riconosciuta al partecipante della riga riconosciuta più vicina nel tempo. Ogni riga ha un partecipante e a omp escono solo le due etichette previste. Costa una piccola euristica nella separazione; con una call in cui nessuna riga è riconosciuta serve comunque un partecipante di ripiego.

## Where in the code

Sources/LARP/Separation/ParticipantSeparator.swift (separate); Sources/LARP/Refinement/RefinementRequest.swift (RefinementSpeaker.others)
