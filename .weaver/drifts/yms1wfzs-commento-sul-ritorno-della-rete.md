---
status: fixed
refs:
- macos.NETWORK_AVAILABLE
task: 0v9dfuam
option: 1
created: 2026-11-11T12:55:09.023Z
decided: 2026-11-11T13:21:33.371Z
---
# Commento sul ritorno della rete

## What happens

Quando la rete torna, oltre a ritentare il **download della lingua** e la **separazione dei partecipanti**, l'app ritenta anche la **rifinitura** delle chiamate in attesa e la **sintesi** delle chiamate in attesa di ritentarla.

## What should happen

Il commento del monitor di rete condiviso dice che lo ascoltano solo le impostazioni (download della lingua) e la macchina della chiamata per **ritentare la separazione**: non nomina la rifinitura né la sintesi.

## Fix options

### Correggere il commento

Elencare nel commento tutti i lavori ritentati al ritorno della rete: download della lingua, separazione, rifinitura e sintesi. Nessun cambio di comportamento.

### Commento generico

Dire solo che il monitor è condiviso da impostazioni e chiamate, senza elencare i lavori, così non invecchia quando se ne aggiunge uno.

## Where in the code

Sources/LARP/Settings/NetworkMonitor.swift; Sources/LARP/Call/CallLifecycle+Separation.swift; Sources/LARP/App/LARPApp.swift

## Prepared question

```json
{
  "question": {
    "id": "yms1wfzs",
    "question": "Come trattare il commento sul ritorno della rete?",
    "context": "Il commento sul NetworkMonitor condiviso dice che solo le impostazioni (scaricamento della lingua) e la macchina delle chiamate (nuovo tentativo di separazione) ascoltano il ritorno della rete, ma quando la rete torna l'app riprova anche la rifinitura e i riassunti in attesa di un nuovo tentativo.",
    "options": [
      {
        "label": "Correggere il commento",
        "description": "Il commento elenca tutto il lavoro che viene riprovato al ritorno della rete: scaricamento della lingua, separazione dei partecipanti, rifinitura e riassunti."
      },
      {
        "label": "Commento generico",
        "description": "Il commento dice solo che il monitor è condiviso da impostazioni e chiamate, senza elencare il lavoro riprovato."
      },
      {
        "label": "Lasciare tutto com'è",
        "description": "Codice e commento restano invariati."
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
      "decision": "dismissed"
    }
  ],
  "fingerprint": "sha256:e987f9ae67657edd1ad9996752d13c36452b0dfb3031dd559c6b96c6accf52d4",
  "prepared": "2026-11-11T12:56:13.419Z"
}
```
