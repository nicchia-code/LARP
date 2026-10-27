---
column: done
technical: false
refs:
  - library
  - main-window
  - transcription
  - user.OPEN_WINDOW
  - user.CLOSE_WINDOW
  - user.SELECT_CALL
  - user.EXPORT_CALL
  - requirements/rules#main-window
  - requirements/ui#main-window
drift: null
proposal: dlpwzchv
agent: false
created: 2026-10-27T10:07:36.916Z
finished: 2026-10-27T10:27:56.510Z
---
# Finestra archivio

Realizzare la finestra dell'archivio (macchina `main-window`): elenco delle call da un lato, call selezionata dall'altro, ricerca ed esportazione in Markdown.

Comportamento, come lo dice il Model:
- **Closed** (iniziale): si vede solo l'icona nella barra dei menu. "Apri archivio" → **Open**.
- **Open**: l'elenco delle call, dalla più recente, filtrabile con una ricerca. Chiudere la finestra → **Closed**.
  - **No call selected** (iniziale): accanto all'elenco non c'è nessuna call. Selezionare una call → **Call selected**.
  - **Call selected**: la call selezionata con titolo, data, durata, stato di avanzamento e, quando c'è, la trascrizione con chi ha parlato in ogni riga. Selezionare un'altra call la mostra. "Esporta…", solo se la call ha una trascrizione, salva la trascrizione come file Markdown dove sceglie l'utente. Se la call mostrata viene eliminata → **No call selected**.

Come costruirlo:
- Vista divisa: a sinistra campo di ricerca ed elenco (titolo, data, durata); a destra la call selezionata. Ogni call non Ready mostra il suo stato: "In registrazione", "In attesa della lingua", "Trascrizione…", "Separazione voci…", "Voci da separare".
- Call selezionata: titolo modificabile sul posto, data, durata, app della call, spazio per i controlli di riascolto (Task "Riascolto sincronizzato") e trascrizione; ogni riga mostra parlante, ora di inizio mm:ss e testo. Clic sul nome di un partecipante per rinominarlo. Rinomina ed eliminazione usano la logica del Task "Gestione call".
- Barra degli strumenti: "Esporta…" (disattivato senza trascrizione) ed "Elimina", che chiede conferma.
- Ricerca: confronta il testo digitato, ignorando maiuscole e accenti, con titolo, testo della trascrizione e nomi dei partecipanti; ricerca vuota mostra tutte le call.
- Esportazione Markdown: H1 con il titolo della call, una riga con data, ora, durata e lingua, poi un paragrafo per riga nella forma `**<parlante>** [<mm:ss>]: <testo>`; nome del file predefinito uguale al titolo.
- Testi in italiano. Test con Swift Testing della ricerca e del formato di esportazione.
