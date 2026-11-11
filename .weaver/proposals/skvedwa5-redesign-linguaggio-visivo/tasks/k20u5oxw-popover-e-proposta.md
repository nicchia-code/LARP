---
refs:
  - recorder
  - capture
  - requirements/ui#recorder
  - requirements/rules#recorder
  - user.START_RECORDING
  - user.ACCEPT_PROPOSAL
  - user.STOP_RECORDING
---
# Popover e proposta

Ridisegna l'icona della barra dei menu, la finestra a comparsa, la proposta di registrare e gli avvisi del Recorder con il nuovo linguaggio visivo. Le schermate della Style Guide (02 barra dei menu) sono allegate a questo Task.

## Cosa deve valere alla fine

- L'icona della barra dei menu è il marchio LARP colorato fuori da una registrazione; durante una registrazione resta il punto rosso `#FF5A40` seguito dal tempo trascorso, aggiornato ogni secondo, in cifre di larghezza uguale (`m:ss`, `h:mm:ss` da un'ora in su; torna a zero alla fine).
- Il clic sull'icona apre una finestra a comparsa scura al posto del menu, 340 px, ink, raggio 18: in alto il marchio LARP con "LARP" e lo stato a destra ("Pronto quando vuoi", "Call rilevata", "In registrazione"); poi la card dello stato; in fondo, dopo un divisore, "Apri archivio" a sinistra e "Impostazioni" ed "Esci" a destra. "Esci" chiude l'app.
- In Idle la card dice "Registrazione manuale", "Nessuna call in corso" e offre "Registra" (lime, a tutta larghezza): `user.START_RECORDING` avvia la registrazione solo con il permesso del microfono (chiesto se non ancora deciso; l'audio di sistema non si controlla), legata a nessuna app; se manca, nulla si registra e compare l'avviso di sistema del permesso mancante.
- Quando un'app di call conosciuta inizia a usare il microfono compare la proposta, una card scura identica ovunque: "In onda ora · <app di call>" con il punto rosso, "Call rilevata" e il pulsante lime "Registra questa call". Resta nel pannellino sotto l'icona che non prende mai il focus, prende il posto della card della finestra a comparsa e compare come banner in cima all'Archivio. Non si può scartare: resta finché viene accettata o l'app smette di usare il microfono; non c'è mai una seconda proposta.
- `user.ACCEPT_PROPOSAL` richiede microfono e audio di sistema, controllati in quest'ordine e detto solo il primo mancante; la proposta scompare ovunque. Con i permessi la registrazione è legata all'app della proposta (anche se nel frattempo ha smesso, allora legata a nessuna app); senza, compare l'avviso del permesso mancante.
- Durante una registrazione la card mostra "In registrazione" con il punto rosso, il titolo della call, il tempo trascorso in JetBrains Mono e il pulsante bianco "Ferma registrazione" con un quadrato ink; `user.STOP_RECORDING` la termina, ogni avviso della registrazione scompare e il tempo torna a zero. Le azioni di pausa e finestra dal vivo arrivano con la Proposal sulla registrazione.
- Gli avvisi sotto l'icona (eco non rimossa, audio di sistema non disponibile, microfono perso, audio di sistema perso) sono card ink 300 px, testo bianco con icona rossa per le perdite e lime per le informazioni, pulsante outline su scuro per aprire Impostazioni di Sistema; tempi e impilamento come nella Requirement. Gli avvisi di permesso mancante o di registrazione non avviata restano avvisi di sistema, con i testi italiani e inglesi della Requirement.
- Il resto del comportamento del Recorder e della cattura non cambia.

## Code notes
Commit: 58d947126f08b8c7e4128d08782a627080bde977
- `Sources/LARP/App/MenuBarContent.swift` `MenuBarContent` (menu di oggi) e `LARPApp.body` in `Sources/LARP/App/LARPApp.swift`: il menu diventa finestra a comparsa.
- `Sources/LARP/Capture/MenuBarLabel.swift` `MenuBarLabel`, `recordingDot` (NSImage non template).
- `Sources/LARP/Capture/RecorderPresenters.swift`: `ProposalPanelController`, `MenuBarPanel` (creazione NSPanel, `origin(for:below:)`, pila), `ProposalView`/`NoticeView`/`EchoCancellationWarningView` con sfondi `.regularMaterial` da sostituire. `MenuBarPanel` trova lo status item con `className.contains("StatusBar")`: fragile.
- `Sources/LARP/Capture/Recorder.swift`: `Recorder` `@Observable` (`state`, `elapsedSeconds` letti direttamente), `.proposing`, `acceptProposal`, `startRecording`.
- `Sources/LARP/Capture/SystemRecordingPermissions.swift` `missingPermission(requireSystemAudio:)`.
- Ogni effetto UI passa da un presenter `@MainActor` dietro protocollo sostituito nei test; mantenere i riferimenti agli eventi del Model nei commenti.
- App `LSUIElement`: `NSApp.activate()` prima di `openWindow`/aprire le Impostazioni.
