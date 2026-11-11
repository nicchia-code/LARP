---
refs:
- main-window
- library
- folder
- requirements/ui#main-window
- requirements/rules#main-window
- requirements/data#folder
- requirements/data#General
- user.FILTER_BY_APP
- user.SHOW_FOLDER
- user.CREATE_FOLDER
- user.RENAME_FOLDER
- user.DELETE_FOLDER
- user.MOVE_TO_FOLDER
- user.COPY_SUMMARY
- user.COPY_TRANSCRIPT
---
# Cartelle, filtri e copia

Quando il lavoro è finito, la finestra principale offre le cartelle, i filtri per app, la ricerca di una parola nella trascrizione, le chip dei parlanti con la loro quota di tempo e la copia di sintesi e trascrizione, come descritti da `main-window`, `folder` e dai Requirements della libreria.

## Cartelle
- L'archivio conserva un settimo tipo di record, la cartella: identificativo, nome e le call che contiene. Una call sta in al più una cartella, che non la possiede; eliminare una cartella lascia le sue call senza cartella. Un archivio salvato prima delle cartelle si apre senza cartelle e con ogni call senza cartella.
- Nella barra laterale, dopo "Tutte le call" e "Segnalibri", l'eyebrow "Cartelle", le cartelle in ordine alfabetico e "+ Nuova cartella", che diventa un campo di testo sul fondo scuro: Invio crea (`user.CREATE_FOLDER`), Esc annulla. Il nome viene ripulito dagli spazi, è lungo al più 60 caratteri e deve essere diverso da quello di ogni altra cartella ignorando maiuscole e accenti; altrimenti non nasce nulla.
- Dal menu contestuale di una cartella: rinomina (`user.RENAME_FOLDER`, con le stesse regole sul nome, altrimenti la cartella tiene il suo nome) ed elimina (`user.DELETE_FOLDER`: le call restano nell'archivio senza cartella; se la cartella mostrata è quella eliminata, la libreria torna su "Tutte le call").
- `user.SHOW_FOLDER` mostra la vista cartella: titolo il nome della cartella, le stesse chip e card di "Tutte le call" ma solo per le sue call; senza call la pagina dice "Nessuna call in questa cartella". Ogni call resta comunque in "Tutte le call".
- Nella pagina della call, "Sposta in cartella" (bottone outline con il nome della cartella attuale, quando c'è) apre un menu con le cartelle e "Nessuna cartella": scegliendo una cartella la call lascia la precedente ed entra in quella; "Nessuna cartella" la toglie dalla sua.

## Filtri per app
- Sopra le card di "Tutte le call" e di una cartella, la riga dei filtri: "Tutte", poi una chip per ogni app di call a cui è legata almeno una call dell'archivio (o della cartella mostrata) in ordine alfabetico, poi "Manuali" se c'è una call registrata a mano e "Importate" se c'è una call importata; a destra il bottone testuale sottolineato "Importa file audio". Chip alte 32 px, la scelta in ink con testo lime.
- `user.FILTER_BY_APP` mostra solo le call della chip scelta, "Tutte" mostra ogni call; la ricerca si applica sopra il filtro. Quando l'app della chip scelta non ha più call, il filtro torna su "Tutte". Ricerca e filtro restano quando si apre una call e si torna alla libreria.
- Sulle card l'app è "Manuale" per una registrazione a mano e "Importata" per un file importato. Una call importata è ordinata per l'ora di ultima modifica del suo file (che è il suo inizio).
- La card mostra la forma d'onda della call, quando ne ha una, in una striscia ink alta 44 px, raggio 10, 10 px di margine laterale: 44 barre colorate per parlante (larghezza flessibile, al più 4 px, 2 px di spazio), barre `#6B6E64` per una call senza righe; la striscia manca finché la forma d'onda non è calcolata. Il calcolo è di un'altra Task.

## Pagina della call
- Una chip per parlante ("Io" solo quando ha righe, e ogni partecipante) con avatar, nome e quota del tempo di parola in JetBrains Mono 11 px: somma di fine meno inizio delle sue righe sul totale di tutti i parlanti, percentuale intera arrotondata al più vicino, chip ordinate per quota decrescente. Le iniziali sono la prima lettera del nome mostrato, o il numero per "Partecipante <numero>". Un clic sulla chip di un partecipante lo rinomina; il link sottolineato "Rinomina parlanti" mette in rinomina la prima chip di partecipante; il campo propone sotto di sé, come chip cliccabili filtrate dal testo, i nomi offerti. La rinomina resta possibile solo per una call pronta.
- Nel pannello della trascrizione, il campo "Trova una parola" (`#F1F1EA`, raggio 16, alto 32 px, lente, conteggio "<n> di <m>" e frecce su e giù mentre c'è testo): il testo viene ripulito e cercato nel testo mostrato di ogni riga ignorando maiuscole, accenti e larghezza dei caratteri; le parole trovate hanno fondo lime e la riga trovata guardata un contorno ink di 2 px; la prima riga mostrata è la prima trovata dopo la riga in ascolto; le frecce girano dall'ultima alla prima e scorrono alla riga. La riga in ascolto resta al centro, tranne mentre si guarda una riga trovata.
- `user.COPY_SUMMARY` ("Copia sintesi", in alto, solo quando la call ha una sintesi) e `user.COPY_TRANSCRIPT` ("Copia trascrizione", link sotto le righe, solo quando la call ha righe) mettono negli appunti la sintesi o la trascrizione con lo stesso testo dell'esportazione Markdown; "Copiata" sostituisce l'etichetta per due secondi; la scheda mostrata non cambia.
- "Elimina tutte le registrazioni" non viene sviluppata.

## Code notes
Commit: 58d947126f08b8c7e4128d08782a627080bde977
- Libreria/pagina: `Sources/LARP/Archive/ArchiveView.swift`, `CallDetailView.swift` (`.id(call.id)`, lo stato si azzera per call), `CallRow.swift`, `TranscriptView.swift` (`TranscriptLineRow`, scroll al centro).
- Ricerca: riusare `CallSearch.normalized` per "Trova una parola" e per i nomi di cartella (case/accenti).
- Copia: riusare `TranscriptExport.markdown` e `SummaryContent.markdownParagraphs` (unica fonte di sintesi per vista, ricerca, export); non duplicare.
- Dati: `Sources/LARP/Model/Call.swift`, `ArchiveStore.swift` `schema` (nessun VersionedSchema): i nuovi campi devono avere default perché i vecchi archivi si aprano (vedi `summaryStateRawValue`).
- Nomi: `CallNaming.swift` `displayTitle`, `Participant.displayName`; rinomina in `CallLifecycle.renameParticipant`.
- Colori dei parlanti: mappatura stabile da `Participant.number`, `.me` in ink.
- I commenti citano gli eventi del Model (`` `user.MOVE_TO_FOLDER` ``); i test logici con swift-testing, fake in `Tests/LARPTests/CallLifecycleFakes.swift`. Nessuna infrastruttura di test UI: testare la logica (filtri, quote, ricerca, regole sui nomi).
