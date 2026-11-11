---
refs:
- settings
- main-window
- requirements/ui#settings
- requirements/data#settings
- requirements/tech#main-window
- user.REVEAL_ARCHIVE
---
# Privacy e archivio

La pagina Impostazioni della finestra principale mostra la sezione "Privacy e archivio" e, nella sezione "Esportazione e integrazioni", la riga "Cartella Markdown", collegate alla conservazione dell'audio e alla cartella Markdown.

## Cosa deve valere

- Sezione **Privacy e archivio**, card bianca con titolo come le altre sezioni, righe separate da divisori `#E4E4DC`:
  - "Conserva i file audio" con la scelta "Sempre", "Per 30 giorni", "Per 90 giorni" e la spiegazione "Trascrizioni e sintesi restano"; la scelta mostra il valore salvato (assente o sconosciuto si mostra "Sempre") e cambiarla è la scelta della conservazione dell'audio.
  - "Posizione dell'archivio" con il percorso dell'archivio sotto, in JetBrains Mono 11 px `#5A5D55`, accorciato con "~", e il bottone outline "Mostra nel Finder". La posizione è solo mostrata, non si può cambiare.
- "Mostra nel Finder": la pagina resta sulle Impostazioni e il Finder si apre selezionando la cartella `LARP` di Application Support, cioè la cartella dell'archivio.
- In **Esportazione e integrazioni**, prima di "Calendario", la riga "Cartella Markdown" con un interruttore e la spiegazione "Salva ogni sintesi e trascrizione come file .md"; mentre è accesa mostra il percorso della cartella in JetBrains Mono 11 px `#5A5D55`, il bottone outline "Cambia" e, quando una scrittura è fallita, "Impossibile scrivere nella cartella" in `#B42A18` finché una scrittura non riesce. Accendere l'interruttore apre la scelta della cartella (annullando resta spento), "Cambia" sceglie un'altra cartella, spegnere lo spegne.
- Le altre sezioni e righe restano come nelle Proposal precedenti; nella barra laterale delle Impostazioni il nome "Privacy e archivio" porta in vista la sezione.
- Non vanno sviluppati "Elimina tutte le registrazioni" né integrazioni con Notion, Slack o email.

## Code notes
Commit: 58d947126f08b8c7e4128d08782a627080bde977
- Pagina: `Sources/LARP/Settings/SettingsView.swift` (oggi `.formStyle(.grouped)`, `.frame(width: 440)`; le Proposal precedenti la portano nella finestra principale con le card), `statusText`, `assistantText`. `SettingsView` prende `LaunchAtLogin` come `@State`, non condiviso.
- Percorso archivio: `Sources/LARP/Model/AppPaths.swift` (radice statica), `ArchiveStore.makeContainer`.
- Ogni effetto di UI passa per un presenter/protocollo `@MainActor` sostituibile nei test: mettere l'apertura del Finder (`NSWorkspace.activateFileViewerSelecting`) dietro un protocollo con fake.
- I commenti nel codice citano gli eventi del Model (es. `user.REVEAL_ARCHIVE`); i testi sono in italiano con il String Catalog it/en.
- Wiring dei controller in `Sources/LARP/App/LARPApp.swift` `init()`.
