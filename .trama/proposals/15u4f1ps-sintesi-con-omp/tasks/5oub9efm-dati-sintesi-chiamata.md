---
technical: true
refs:
  - requirements/data#call
---
# Sintesi salvata sulla chiamata

Ogni chiamata (`@Model Call` in Model/Call.swift, schema in Model/ArchiveStore.swift) contiene al massimo una sintesi: i concetti chiave, le decisioni e i prossimi passi come liste ordinate di testi, ogni prossimo passo con un responsabile facoltativo ("Io" o "Partecipante <numero>"), il testo libero, la lingua in cui è scritta e quando è stata scritta. La chiamata contiene anche lo stato della sua sintesi, separato da `CallState`: nessuna, in scrittura, in attesa di nuovo tentativo, scritta. La sintesi salvata conserva "Io" e "Partecipante <numero>" così come li ha scritti l'assistente; la sostituzione con i nomi dati dall'utente avviene solo quando la si mostra, cerca o esporta.

Le chiamate salvate prima che esistessero le sintesi si aprono senza errori e risultano senza sintesi (stato «nessuna»): i nuovi campi devono essere facoltativi o con valore predefinito, così che lo store esistente continui ad aprirsi.

Eliminare una chiamata elimina il suo record, le sue righe, i suoi partecipanti, la sua sintesi e la cartella `Recordings/<id chiamata>/`. Restano valide tutte le altre regole del dato chiamata: file audio `mic.caf`/`system.caf`, righe con testo e parlante originali dopo la rifinitura, partecipanti numerati appartenenti a una sola chiamata.
