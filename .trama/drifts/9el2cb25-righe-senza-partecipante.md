---
status: resolved
resolution: fix-code
refs:
  - requirements/rules#call
  - call.PARTICIPANTS_SEPARATED
proposal: null
task: vjcr36fd
origin: null
option: 1
note: null
resolvedBy: lrcud1ui
created: 2026-10-27T13:15:52.039Z
job: c421f323-4d86-420b-81df-714ff3658f41
---
# Righe senza partecipante

## What happens

Se la separazione per voce non riesce ad assegnare una riga di "Altri" a nessun partecipante, la riga resta "Altri". La rifinitura la manda a omp con l'etichetta **"Altri"**, che il testo dei Requirements non elenca, e permette di lasciarla "Altri" o di passarla a un partecipante.

## What should happen

Il Model dice che ogni riga di "Altri" va a un partecipante, e i Requirements dicono che a omp esce chi parla solo come **"Io"** o **"Partecipante <numero>"**. Il caso di una riga senza partecipante non è previsto, e la scelta cambia cosa esce dal Mac e cosa viene salvato.

## Fix options

### Partecipante più vicino

La separazione assegna ogni riga non riconosciuta al partecipante della riga riconosciuta più vicina nel tempo. Ogni riga ha un partecipante e a omp escono solo le due etichette previste. Costa una piccola euristica nella separazione; con una call in cui nessuna riga è riconosciuta serve comunque un partecipante di ripiego.

### Partecipante di ripiego

Le righe non riconosciute vanno tutte a un partecipante aggiuntivo della call, numerato dopo gli altri. A omp escono solo le due etichette previste. Costa un partecipante che può raccogliere voci diverse, rinominabile dall'utente.

## Where in the code

Sources/LARP/Separation/ParticipantSeparator.swift (separate); Sources/LARP/Refinement/RefinementRequest.swift (RefinementSpeaker.others)

## Prepared question

```json
{
  "question": {
    "id": "9el2cb25",
    "question": "Come va trattata una riga di \"Altri\" che la separazione non assegna a nessun partecipante?",
    "context": "Dopo la separazione per voce, ogni riga di \"Altri\" dovrebbe andare a un partecipante. Può però succedere che una riga non venga riconosciuta. I Requirements dicono che a omp esce chi parla solo come \"Io\" o \"Partecipante <numero>\", quindi per questo caso non dicono cosa mandare né cosa salvare.",
    "options": [
      {
        "label": "Partecipante più vicino",
        "description": "La riga va al partecipante della riga riconosciuta più vicina nel tempo; a omp escono solo le due etichette previste."
      },
      {
        "label": "Partecipante di ripiego",
        "description": "Le righe non riconosciute vanno a un partecipante aggiuntivo, numerato dopo gli altri."
      },
      {
        "label": "Riga \"Altri\" a omp",
        "description": "La riga resta \"Altri\" e viene mandata a omp con quell'etichetta; può restare \"Altri\" o passare a un partecipante. I Requirements lo dicono esplicitamente."
      }
    ],
    "recommended": 0,
    "multi": false
  },
  "decisions": [
    {
      "decision": "fix-code",
      "option": 1
    },
    {
      "decision": "fix-code",
      "option": 2
    },
    {
      "decision": "proposal"
    }
  ],
  "fingerprint": "9595d719f508de2404ba5d2f16bce52bfb898841be34b0b28c12474be9f9df7f",
  "prepared": "2026-10-27T13:15:56.599Z"
}
```
