---
status: fixed
refs:
- requirements/rules#transcription
task: tgd5lphx
option: 1
created: 2026-11-11T12:55:09.072Z
decided: 2026-11-11T13:22:49.154Z
---
# Commento sul limite di omp

## What happens

Le richieste di **rifinitura** e di **sintesi** concedono a omp fino a **600 secondi** in tutto, la prima risposta di apertura compresa. I **10 secondi** valgono solo per la verifica che omp sia raggiungibile.

## What should happen

Il commento della costante di 10 secondi dice che è il tempo che omp ha per rispondere all'apertura della conversazione, **senza eccezioni**: chi lo legge si aspetta che anche rifinitura e sintesi falliscano dopo 10 secondi senza risposta.

## Fix options

### Correggere il commento

Scrivere che i 10 secondi sono il limite della verifica di omp e il valore predefinito, mentre rifinitura e sintesi passano il proprio limite di 600 secondi. Nessun cambio di comportamento.

### Rinominare la costante

Dare alla costante un nome e un commento della verifica di raggiungibilità, togliendola come valore predefinito dell'apertura, così ogni chiamante passa il suo limite. Nessun cambio di comportamento.

## Where in the code

Sources/LARP/Assistant/Omp.swift; Sources/LARP/Assistant/TranscriptRefiner.swift

## Prepared question

```json
{
  "question": {
    "id": "vrrdqoze",
    "question": "Il commento sulla costante di 10 secondi in Omp.swift dice che è il tempo di risposta all'apertura senza eccezioni, ma le richieste di rifinitura e riassunto concedono a omp fino a 600 secondi in totale. Come procedere?",
    "options": [
      {
        "label": "Correggere il commento",
        "description": "Riscrivere il commento: 10 secondi valgono solo per il controllo di raggiungibilità, le richieste concedono fino a 600 secondi apertura inclusa."
      },
      {
        "label": "Rinominare la costante",
        "description": "Dare alla costante nome e commento da limite del controllo di raggiungibilità, non più valore predefinito dell'apertura, senza cambiare il comportamento."
      },
      {
        "label": "Lasciare tutto com'è",
        "description": "Non modificare né il commento né il codice."
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
  "fingerprint": "sha256:84b181824b4d0dd517df21fbd5a23a8acc40d97752ca3bbcbdb7da64537c2ed0",
  "prepared": "2026-11-11T12:55:55.552Z"
}
```
