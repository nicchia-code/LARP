---
status: resolved
resolution: fix-code
refs:
  - call/Recording
  - call/Transcribing
proposal: null
task: 43a6o9u3
origin: null
unifies:
  - 67htup6g
  - 1irsgxey
option: 1
note: null
resolvedBy: g47gg1gy
created: 2026-10-27T11:13:42.198Z
job: a80d6904-f47b-464b-a045-92f780a5a52a
---
# Fallimenti di cattura e trascrizione

## What happens

Quando qualcosa fallisce nella vita di una call l'utente non viene avvisato:

- se la registrazione parte ma la cattura non si avvia (permesso revocato, nessun microfono, errore di sistema), la call appena nata viene **eliminata** in silenzio e non resta traccia di quella registrazione;
- se la trascrizione dall'audio salvato fallisce, la call resta in **Transcribing** senza avviso e viene ritentata solo al lancio successivo dell'app; fino ad allora l'utente non vede né trascrizione né errore.

## What should happen

Il Model non descrive nessuno dei due fallimenti: **Recording** non ha transizioni per una cattura che non parte e **Transcribing** esce solo con il completamento o con l'eliminazione. La scelta cambia cosa vede l'utente, quali dati restano e quando si riprova.

## Fix options

### Avvisare in entrambi i casi

Se la cattura non parte la call viene eliminata e l'utente riceve un avviso che dice che la registrazione non è partita e perché. Se la trascrizione fallisce la call mostra che non è riuscita e si riprova da sola dopo un'attesa, senza nuovo stato. Costa un avviso, un'indicazione sulla call e una regola di ritentativo.

### Avvisare solo alla cattura

Se la cattura non parte la call viene eliminata e l'utente riceve un avviso. La trascrizione fallita resta com'è oggi: nessun avviso e nuovo tentativo al lancio successivo. Costa solo l'avviso, ma una call può restare ferma a lungo senza spiegazione.

### Call vuota e attesa lingua

Se la cattura non parte la call resta nell'archivio senza audio, così il tentativo fallito è visibile; va eliminata a mano. Se la trascrizione fallisce la call passa ad **Awaiting language**, che già riprova da sola, anche se il nome dello stato non descrive la causa.

## Where in the code

- Sources/LARP/Call/CallLifecycle+Recording.swift, avvio della registrazione di CallLifecycle (cattura che non parte)
- Sources/LARP/Call/CallLifecycle+Transcription.swift, ciclo di trascrizione di CallLifecycle (trascrizione da file fallita)

## Prepared question

```json
{
  "question": {
    "id": "uu9tx8op",
    "question": "Cosa deve succedere quando la cattura audio non parte o la trascrizione dall'audio salvato fallisce?",
    "context": "Il Model non descrive nessuno dei due fallimenti: lo stato **Recording** non ha transizioni per una cattura che non parte (permesso revocato, nessun microfono, errore di sistema) e lo stato **Transcribing** esce solo con il completamento o con l'eliminazione. La scelta cambia cosa vede l'utente, quali dati restano e quando si riprova.",
    "options": [
      {
        "label": "Avvisare in entrambi i casi",
        "description": "Cattura fallita: la call viene eliminata e l'utente riceve un avviso. Trascrizione fallita: la call lo mostra e si riprova da sola dopo un'attesa.",
        "details": "Pro: l'utente sa sempre cosa è successo e la trascrizione riparte presto. Contro: un avviso, un'indicazione sulla call e una regola di ritentativo da aggiungere."
      },
      {
        "label": "Avvisare solo alla cattura",
        "description": "Cattura fallita: la call viene eliminata e l'utente riceve un avviso. Trascrizione fallita: nessun avviso, nuovo tentativo al lancio successivo dell'app.",
        "details": "Pro: poco lavoro, l'utente non crede di registrare quando non succede. Contro: una call può restare senza trascrizione a lungo senza spiegazione."
      },
      {
        "label": "Call vuota e attesa lingua",
        "description": "Cattura fallita: la call resta nell'archivio senza audio. Trascrizione fallita: la call passa ad **Awaiting language**, che riprova da sola.",
        "details": "Pro: il tentativo fallito resta visibile e la trascrizione riparte da sola riusando uno stato esistente. Contro: call inutili da eliminare a mano e un nome di stato che non descrive la causa."
      },
      {
        "label": "Descrivere nel Model eliminazione e nuovo tentativo al lancio",
        "description": "Il Model aggiunge i due fallimenti: la call senza cattura viene eliminata senza avviso, la trascrizione fallita riparte al lancio successivo senza avviso. Il codice non cambia.",
        "details": "Pro: nessun lavoro sul codice. Contro: l'utente può credere di registrare e non vede perché una call resta senza trascrizione."
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
  "fingerprint": "072a927586aeb1ed83460daac07fbb28a69a781c3babdc8cc8264c4f721f8aba",
  "prepared": "2026-10-27T11:13:51.824Z"
}
```
