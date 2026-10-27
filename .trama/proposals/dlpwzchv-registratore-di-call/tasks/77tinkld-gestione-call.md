---
refs:
  - call/Ready
  - call/Deleted
  - call.DELETED
  - user.RENAME_CALL
  - user.RENAME_PARTICIPANT
  - user.DELETE_CALL
---
# Gestione call

Realizzare rinomina ed eliminazione delle call e la rinomina dei partecipanti, cioè lo stato **Ready**, lo stato finale **Deleted** e le stesse azioni negli altri stati in cui il Model le ammette.

Comportamento, come lo dice il Model:
- Rinomina call: possibile negli stati Awaiting language, Transcribing, Separating participants, Awaiting separation retry e Ready; la call prende il nuovo titolo e resta nello stesso stato. Non è possibile durante Recording.
- Eliminazione call (dopo conferma dell'utente): possibile negli stessi stati → **Deleted**. Ferma la trascrizione o la separazione in corso ed elimina audio, trascrizione (anche parziale), partecipanti e la cartella `Recordings/<id call>/`. Si emette `DELETED`.
- **Ready**: la trascrizione è completa e ogni riga dice chi ha parlato, "Io" o un partecipante. Rinomina partecipante: il partecipante prende il nuovo nome in tutta la trascrizione di questa call, e solo di questa call.
- **Deleted** (finale): la call, il suo audio e la sua trascrizione non esistono più.

Regole:
- Una call senza titolo si mostra come "Call del <giorno> <mese> <anno>, <hh:mm>" con il mese in italiano, per esempio "Call del 27 ottobre 2026, 10:41".
- Un partecipante senza nome si mostra come "Partecipante <numero>"; il parlante Me si mostra come "Io", Others come "Altri".
- Un titolo o un nome vuoto dati dall'utente ripristinano quello predefinito.
- Test con Swift Testing di rinomina, nomi predefiniti ed eliminazione (file compresi).
