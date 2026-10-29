---
column: done
technical: false
refs:
  - main-window/Call selected
  - main-window/No call selected/user.SELECT_CALL
  - requirements/ui#main-window
  - requirements/ui#call-summary
drift: null
proposal: 15u4f1ps
agent: false
created: 2026-10-28T19:23:51.370Z
finished: 2026-10-28T19:28:08.809Z
---
# Sintesi nella finestra archivio

Nella finestra archivio (`ArchiveView`, `CallDetailView`), la chiamata selezionata mostra titolo (modificabile sul posto), data, durata, app della chiamata, i controlli di riproduzione e, sotto di essi, un controllo segmentato «Sintesi» / «Trascrizione» che mostra uno dei due. Con `user.SELECT_CALL`, sia da No call selected sia da Call selected, la chiamata scelta si apre su «Sintesi» quando ha una sintesi, altrimenti su «Trascrizione». La scheda «Sintesi» è sempre presente. In «Trascrizione» ogni riga resta come oggi: parlante, ora di inizio mm:ss e testo; cliccando il nome di un partecipante lo si rinomina.

«Sintesi» mostra le sezioni in ordine fisso: concetti chiave, decisioni, prossimi passi, poi il testo libero, ognuna col suo titolo e le voci come elenco puntato; un prossimo passo con un responsabile mostra il nome dopo il testo. I titoli seguono la lingua della sintesi: «Concetti chiave», «Decisioni», «Prossimi passi», «Altro» in italiano; «Key concepts», «Decisions», «Next steps», «Other» in inglese. Un elenco vuoto mostra «Nessuno» (italiano) o «None» (inglese); «Altro»/«Other» è omesso quando il testo libero è vuoto. Ogni «Partecipante N» è mostrato col nome attuale dato dall'utente a quel partecipante, se c'è; la sintesi salvata conserva «Io» e «Partecipante N». La sintesi è in sola lettura, ma il testo si può selezionare e copiare.

Sopra la sintesi o al suo posto, secondo lo stato della Machine `call-summary`: «Sintesi in corso…» in Summarising, «Sintesi non riuscita, nuovo tentativo appena possibile» in Awaiting summary retry, «Nessuna sintesi» quando la chiamata non ne ha e nessuna è in scrittura. Durante il rifacimento o dopo un tentativo fallito la sintesi precedente resta visibile sotto il messaggio.

Nell'elenco (`CallRow`, `CallState.statusLabel`), una chiamata Ready mostra «Sintesi…» mentre la sintesi è in scrittura e «Sintesi da fare» mentre attende un nuovo tentativo; le altre etichette di stato restano invariate.

La toolbar aggiunge «Sintetizza», abilitato solo quando le sintesi sono attive, la trascrizione ha almeno una riga, i partecipanti sono stati distinti e nessuna sintesi è in scrittura per la chiamata; vale anche per chiamate vecchie. Premendolo si invia `user.SUMMARIZE_CALL`, gestito dal codice di `call-summary` (non parte di questo Task); la nuova sintesi sostituisce quella vecchia. Le altre azioni («Esporta…», «Rifinisci testo», «Ripristina originale», «Elimina» con conferma) restano come sono. `call.DELETED` della chiamata mostrata porta a No call selected; `user.EXPORT_CALL` è descritto nel Task di ricerca ed esportazione.
