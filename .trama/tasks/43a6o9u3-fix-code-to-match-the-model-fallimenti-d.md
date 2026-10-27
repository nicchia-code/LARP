---
column: done
technical: false
refs:
  - call/Recording
  - call/Transcribing
drift: uu9tx8op
proposal: null
agent: false
created: 2026-10-27T11:18:26.693Z
finished: 2026-10-27T11:21:14.137Z
---
# Fix code to match the Model: Fallimenti di cattura e trascrizione

## What happens

Quando qualcosa fallisce nella vita di una call l'utente non viene avvisato:

- se la registrazione parte ma la cattura non si avvia (permesso revocato, nessun microfono, errore di sistema), la call appena nata viene **eliminata** in silenzio e non resta traccia di quella registrazione;
- se la trascrizione dall'audio salvato fallisce, la call resta in **Transcribing** senza avviso e viene ritentata solo al lancio successivo dell'app; fino ad allora l'utente non vede né trascrizione né errore.

## What should happen

Il Model non descrive nessuno dei due fallimenti: **Recording** non ha transizioni per una cattura che non parte e **Transcribing** esce solo con il completamento o con l'eliminazione. La scelta cambia cosa vede l'utente, quali dati restano e quando si riprova.

## Chosen option

**Avvisare in entrambi i casi**

Se la cattura non parte la call viene eliminata e l'utente riceve un avviso che dice che la registrazione non è partita e perché. Se la trascrizione fallisce la call mostra che non è riuscita e si riprova da sola dopo un'attesa, senza nuovo stato. Costa un avviso, un'indicazione sulla call e una regola di ritentativo.

## Where in the code

- Sources/LARP/Call/CallLifecycle+Recording.swift, avvio della registrazione di CallLifecycle (cattura che non parte)
- Sources/LARP/Call/CallLifecycle+Transcription.swift, ciclo di trascrizione di CallLifecycle (trascrizione da file fallita)
