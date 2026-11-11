---
refs:
  - main-window
  - playback
  - requirements/ui#main-window
  - requirements/ui#playback
  - user.SELECT_BOOKMARK
  - user.SHOW_ALL_CALLS
  - user.SHOW_BOOKMARKS_VIEW
  - user.SHOW_SUMMARY
  - user.SHOW_NOTES
  - user.SHOW_BOOKMARKS
---
# Schede della call e Segnalibri

La finestra principale guadagna la vista "Segnalibri" di tutte le call e le schede "Sintesi", "Le mie note" e "Segnalibri" nella pagina di una call.

## Cosa deve valere

- **Barra laterale**: "Nuova registrazione" (lime, con la scorciatoia, disattivato al 40 % mentre qualcosa è proposto o registrato) avvia una registrazione a mano senza cambiare pagina; voci "Tutte le call" e "Segnalibri", la selezionata `#23251F` con testo lime.
- **Archivio**: due viste, "Tutte le call" (iniziale, titolo "Tutto quello che è stato detto.") e "Segnalibri". La ricerca resta aprendo una call e tornando. Tornando da una call (con "‹ Archivio" o dopo l'eliminazione) l'Archivio riprende la vista da cui era stata aperta (assunzione dell'agente). Il banner "In onda ora" accetta o scarta la proposta.
- **Vista Segnalibri**: i segnalibri delle call che corrispondono alla ricerca, raggruppati per call, call più recente prima e in ordine di tempo dentro una call; una card bianca per call con eyebrow (giorno, ora, app) e titolo, una riga per segnalibro con il tempo in un chip JetBrains Mono `#ECECE4` e il testo della riga di trascrizione a quel tempo, se c'è (al più due righe), evidenziata `#F1F1EA` sotto il puntatore. Senza segnalibri "Nessun segnalibro". SELECT_BOOKMARK apre la pagina della call sulla scheda Segnalibri, ne carica l'audio e lo riproduce dal segnalibro.
- **Pagina della call**: si apre sulla Sintesi. Le schede in Bricolage Grotesque 18 px, la selezionata ink con sottolineatura lime di 3 px; "Sintetizza"/"Rigenera" a destra solo sulla Sintesi. Rinominare la call o un partecipante ed esportare lasciano la scheda com'era; annullare l'eliminazione torna sulla scheda mostrata prima.
  - **Le mie note**: una riga per nota con il tempo in un chip (nessuno senza tempo), testo modificabile sul posto, bottone elimina sotto il puntatore; in fondo il campo "Scrivi una nota…" che aggiunge con Invio. Senza note "Nessuna nota".
  - **Segnalibri**: una riga per segnalibro con tempo, testo della riga a quel tempo, elimina sotto il puntatore; un clic riproduce da lì. Senza segnalibri "Nessun segnalibro".
  - **Trascrizione**: la riga all'ora di un segnalibro porta "⌑ SEGNALIBRO" a destra dell'eyebrow.
- **Riproduzione**: SELECT_BOOKMARK da fermo riproduce dal segnalibro se la call ha audio, caricandolo prima se non è quella mostrata; in riproduzione o in pausa riprende dal segnalibro. La barra ha un bottone tondo 36 px "Segnalibro" su `#2A2C26` che segna il tempo raggiunto; piccoli tick lime sopra la timeline segnano i segnalibri; senza audio "Audio non disponibile" con play e segnalibro disattivati. Durante la registrazione la barra non c'è.

## Code notes
Commit: 58d947126f08b8c7e4128d08782a627080bde977
- `Sources/LARP/Archive/ArchiveView.swift` `ArchiveView` (split view, ricerca, dialogo di eliminazione, `.callDeleted`); `CallDetailView.swift` (header, scheda, `show()`/`updateTimeline()`), è `.id(call.id)` quindi lo stato si azzera per call: la scheda iniziale per SELECT_BOOKMARK va passata da fuori.
- `TranscriptView.swift` `TranscriptView`, `TranscriptLineRow`; `CallRow.swift`; `CallSearch.swift` `CallSearch.normalized`, `fields` per filtrare la vista Segnalibri.
- Riproduzione: `Sources/LARP/Playback/PlaybackController.swift` (`show`, `setTimeline`, `seek`, `play(fromSentenceStart:)`), `PlaybackControlsView.swift`, `TranscriptTimeline.swift` `LineTiming` per trovare la riga a un tempo.
- Avvio manuale: `Recorder.startRecording` in `Sources/LARP/Capture/Recorder.swift`.
- Testi in italiano; commenti con gli eventi (`user.SELECT_CALL`); niente test UI, testare solo la logica (raggruppamento, ordine, ricerca) con Swift Testing.
