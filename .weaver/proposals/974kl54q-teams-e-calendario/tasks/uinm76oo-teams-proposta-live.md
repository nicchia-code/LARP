---
refs:
- recorder
- recording-view
- onboarding
- settings
- requirements/ui#recorder
- requirements/ui#onboarding
- requirements/ui#settings
- requirements/data#settings
---
# Teams in proposta e live

Le informazioni di Teams e del calendario compaiono nella proposta, nella finestra a comparsa, nella finestra dal vivo, nel benvenuto e nelle Impostazioni. Quando il lavoro è finito valgono le condizioni seguenti.

## Proposta e finestra a comparsa
- La card della proposta (pannello, finestra a comparsa e banner "In onda ora" dell'archivio) mostra come titolo il titolo della riunione di Teams, altrimenti il titolo dell'evento del calendario in corso, altrimenti "Call rilevata", e sotto, quando noto, il numero di persone della riunione da Teams, altrimenti dagli invitati dell'evento (contando anche l'utente). Nel banner il titolo è in Bricolage Grotesque 24 px con il numero di persone in 13 px `#A3A69B`.
- Durante una registrazione con accesso a Teams e riunione mostrata, finestra a comparsa e finestra dal vivo mostrano titolo e numero di persone.
- A riposo, con il calendario collegato e riunioni in arrivo, sotto la card compare l'eyebrow "Prossime" e una riga per riunione (al massimo tre): ora di inizio in JetBrains Mono lime, titolo in 13 px `#E9EAE3`, app di call a destra in `#A3A69B`.
- Quando l'accesso a Teams era stato concesso a una versione precedente e ora manca, la finestra a comparsa mostra la riga "Consenti di nuovo l'accesso a Teams" in `#FFCFAE`, che apre le Impostazioni.

## Finestra dal vivo
- Mentre Teams mostra la riunione della call e "Identifica i parlanti" è acceso, una riga di "Altri" mostra invece il nome che Teams indicava come parlante al suo inizio, quando c'era; "Nella call" elenca "Io" e le persone mostrate da Teams, segnando chi Teams indica come parlante. Ciò vale solo per la vista: non cambia nulla di salvato nelle righe. Quando Teams non mostra chi parla, o l'interruttore è spento, le righe restano "Altri".

## Benvenuto
- Nel passo "Passo 1 di 2 · Permessi", dopo microfono e audio di sistema, due righe facoltative (nome con "· facoltativo" in `#5A5D55`): "03" Microsoft Teams, "Titolo della riunione e chi parla, letti con l'Accessibilità", con "Consenti" (pulsante scuro), e "04" il calendario, "Dà il nome alle registrazioni e indica chi c'era", con "Collega" (pulsante outline); ciascuna passa la scelta all'accesso a Teams o al calendario e, una volta fatto, mostra il chip lime "✓ Consentito" o "✓ Collegato". Si può continuare anche senza.

## Impostazioni
- In "Trascrizione": "Identifica i parlanti" con interruttore e la spiegazione "Usa i nomi di Teams e degli invitati del calendario".
- In "Esportazione e integrazioni": "Calendario" con la spiegazione "Collegato · dà il nome alle registrazioni e indica chi c'era", "Non collegato" o "Accesso negato in Impostazioni di Sistema", e il pulsante outline "Collega" o "Scollega"; "Microsoft Teams" con la spiegazione "Titolo della riunione, partecipanti e chi parla, letti con l'Accessibilità; Teams usa un po' più di processore" e a destra "Consenti" (scuro), "In attesa…" durante l'attesa del permesso o il chip lime "✓ Consentito"; quando il permesso è stato perso dopo un aggiornamento la spiegazione diventa "Da consentire di nuovo dopo l'aggiornamento" in `#B42A18`.
- L'apertura delle Impostazioni rilegge il permesso di Teams e l'accesso al calendario.
- Impostazioni salvate: "calendario collegato" (default no), "Identifica i parlanti" (default sì), "accesso a Teams visto concesso" (default no); permesso Accessibilità e accesso al calendario solo in memoria.
- Nessun dato di Teams o del calendario va a omp.

## Code notes
Commit: 58d947126f08b8c7e4128d08782a627080bde977
- Proposta e card: `Sources/LARP/Capture/RecorderPresenters.swift` (`ProposalPanelController`, `ProposalView`, `MenuBarPanel`); finestra a comparsa `Sources/LARP/App/MenuBarContent.swift`; stato in `Sources/LARP/Capture/Recorder.swift` (`@Observable`, SwiftUI legge `state`).
- Banner archivio: `Sources/LARP/Archive/ArchiveView.swift`.
- Finestra dal vivo e benvenuto vengono dalla Proposal precedente (P2); impostazioni in `Sources/LARP/Settings/SettingsView.swift` (`LaunchAtLogin` come `@State`, non condiviso).
- Ogni effetto UI passa da un presenter `@MainActor` dietro protocollo sostituito nei test.
- App `LSUIElement`: `NSApp.activate()` prima di `openWindow`/`SettingsLink`.
- Chiavi in `Sources/LARP/Settings/SettingsKey.swift`.
- Nessuna infrastruttura di test UI: testabili solo formatter e tabelle di stato; il resto si verifica a mano.
- Testi in italiano nel String Catalog con fallback inglese; i commenti citano gli Event del Model.
