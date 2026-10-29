---
technical: false
refs:
  - main-window/Call selected/user.EXPORT_CALL
  - requirements/rules#main-window
---
# Ricerca ed esportazione sintesi

La ricerca dell'archivio (`CallSearch.fields(of:)`) confronta il testo digitato, ignorando maiuscole e accenti, con titolo, testo della trascrizione, nomi dei partecipanti e testo della sintesi così come è mostrato, cioè con i nomi attuali al posto di «Partecipante N» e con i titoli di sezione; una ricerca vuota mostra tutte le chiamate. Ricerca ed esportazione usano testo e parlanti che la chiamata mostra: rifiniti, oppure originali dopo un ripristino. Le sintesi esistenti restano ricercabili ed esportabili anche con le sintesi disattivate.

L'esportazione Markdown (`TranscriptExport.markdown(for:)`, con `user.EXPORT_CALL` solo se la chiamata ha una trascrizione): un H1 col titolo, una riga con data, ora, durata e lingua, poi un paragrafo per riga come `**<parlante>** [<mm:ss>]: <testo>`; nome file predefinito il titolo. Quando la chiamata ha una sintesi, tra la riga della data e le righe vanno: `## Sintesi`, poi un `### <titolo sezione>` per sezione con l'elenco come `- <testo>` (un prossimo passo con responsabile come `- <testo> (<chi>)`, con il nome attuale al posto di «Partecipante N») e il testo libero come paragrafo, quindi `## Trascrizione` prima delle righe. Titoli di sezione, «Nessuno»/«None» per elenchi vuoti e omissione di «Altro»/«Other» vuoto seguono le stesse regole della vista. Senza sintesi il file resta identico a oggi, senza intestazioni `##`.
