---
status: resolved
resolution: unified
refs:
  - call/Recording
proposal: null
task: null
origin: null
unifiedInto: uu9tx8op
option: null
note: null
created: 2026-10-27T10:35:03.592Z
job: 1eb6b0f2-f1a7-4bcc-8957-50a0dda449b7
---
# Avvio cattura fallito

## What happens

Se la registrazione parte ma la cattura non si avvia (permesso revocato, nessun microfono, errore di sistema), la call appena nata viene **eliminata** in silenzio e l'utente non vede nulla: non resta traccia di quella registrazione.

## What should happen

Il Model non dice cosa succede quando la cattura non parte dopo l'avvio della registrazione: **Recording** non ha transizioni per questo caso. La scelta cambia cosa vede l'utente e quali dati restano.

## Fix options

### Eliminare e avvisare

La call viene eliminata come ora, ma l'utente riceve un avviso che dice che la registrazione non è partita e perché. Nessun dato spurio resta; costa solo un avviso in più.

### Tenere la call vuota

La call resta nell'archivio senza audio, così l'utente vede il tentativo fallito. Costa una call inutile da eliminare a mano e uno stato che il Model non prevede.

### Eliminare in silenzio

Comportamento attuale, da confermare: nessun avviso. Semplice, ma l'utente crede di registrare.

## Where in the code

Sources/LARP/Call/CallLifecycle+Recording.swift, avvio della registrazione di CallLifecycle

## Prepared question

```json
{
  "question": {
    "id": "67htup6g",
    "question": "Cosa deve succedere quando la cattura audio non parte dopo l'avvio di una registrazione?",
    "context": "Il Model non descrive il caso: lo stato **Recording** non ha transizioni per una cattura che fallisce (permesso revocato, nessun microfono, errore di sistema). La scelta cambia cosa vede l'utente e quali dati restano.",
    "options": [
      {
        "label": "Eliminare la call e avvisare",
        "description": "La call nata viene eliminata e l'utente riceve un avviso che spiega che la registrazione non è partita."
      },
      {
        "label": "Tenere la call vuota",
        "description": "La call resta nell'archivio senza audio, così il tentativo fallito è visibile; va eliminata a mano."
      },
      {
        "label": "Eliminare la call senza avviso",
        "description": "La call nata viene eliminata in silenzio: nessun avviso, ma l'utente può credere di registrare."
      },
      {
        "label": "Descrivere nel Model l'eliminazione senza avviso",
        "description": "Il Model aggiunge l'evento di cattura fallita e la transizione di Recording verso Deleted, senza avviso, senza cambiare il codice."
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
  "fingerprint": "997691832091c1f5bf9551b7dbe25e3bfc71080a68790eab49f0c47a24817864",
  "prepared": "2026-10-27T10:35:58.330Z"
}
```
