---
status: resolved
resolution: unified
refs:
  - call/Transcribing
proposal: null
task: null
origin: null
unifiedInto: uu9tx8op
option: null
note: null
created: 2026-10-27T10:35:03.736Z
job: 1eb6b0f2-f1a7-4bcc-8957-50a0dda449b7
---
# Trascrizione da file fallita

## What happens

Se la trascrizione dall'audio salvato fallisce, la call resta in **Transcribing** senza avviso e viene ritentata solo al lancio successivo dell'app; fino ad allora l'utente non vede né trascrizione né errore.

## What should happen

Il Model non prevede un fallimento della trascrizione da file: **Transcribing** esce solo con il completamento o con l'eliminazione. La scelta cambia cosa vede l'utente e quando si riprova.

## Fix options

### Ritentare da subito e avvisare

Dopo un fallimento la call mostra che la trascrizione non è riuscita e si riprova dopo un'attesa. Costa un'indicazione visibile e una regola di ritentativo, senza nuovo stato.

### Ritentare solo al lancio

Comportamento attuale, da confermare: nessun avviso e nuovo tentativo al prossimo avvio. Semplice, ma la call può restare ferma a lungo senza spiegazione.

### Tornare ad attesa lingua

Dopo il fallimento la call passa a **Awaiting language**, che già riprova da sola. Riusa uno stato esistente, ma il nome non descrive la causa.

## Where in the code

Sources/LARP/Call/CallLifecycle+Transcription.swift, ciclo di trascrizione di CallLifecycle

## Prepared question

```json
{
  "question": {
    "id": "1irsgxey",
    "question": "Cosa deve succedere quando la trascrizione di una call dall'audio salvato fallisce?",
    "context": "Il Model non descrive il caso: lo stato **Transcribing** esce solo con il completamento o con l'eliminazione. La scelta cambia cosa vede l'utente e quando si riprova.",
    "options": [
      {
        "label": "Avvisare e ritentare dopo un'attesa",
        "description": "La call mostra che la trascrizione non è riuscita e si riprova da sola dopo un'attesa, senza nuovo stato."
      },
      {
        "label": "Ritentare solo al lancio successivo",
        "description": "Nessun avviso; la call resta ferma finché l'app non viene riaperta."
      },
      {
        "label": "Passare ad attesa lingua",
        "description": "La call va in **Awaiting language**, che già riprova da sola; il nome dello stato non descrive la causa."
      },
      {
        "label": "Descrivere nel Model il nuovo tentativo al lancio",
        "description": "Il Model aggiunge l'evento di trascrizione fallita e la transizione di Transcribing su se stesso con nuovo tentativo al lancio, senza avviso, senza cambiare il codice."
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
      "decision": "fix-code",
      "option": 3
    },
    {
      "decision": "proposal"
    }
  ],
  "fingerprint": "6e9a5ca4b856004c8edb0c2e42de69bc43acc4007d822075e856eab362ccd6e7",
  "prepared": "2026-10-27T10:35:58.395Z"
}
```
