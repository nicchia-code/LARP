---
refs:
- call
- main-window
- speaker-identification
- requirements/data#call
- requirements/rules#call
- requirements/rules#call/Separating participants
- requirements/ui#main-window
- user.TURN_ON_SPEAKER_IDENTIFICATION
- user.TURN_OFF_SPEAKER_IDENTIFICATION
---
# Titoli e nomi dalle riunioni

Le call prendono titolo e nomi dei partecipanti dalla riunione di Teams e dall'evento del calendario. Quando il lavoro è finito valgono le condizioni seguenti.

## Informazioni della riunione nella call
- Ogni call può tenere, tutte facoltative perché un archivio salvato prima si apra senza di esse: il **titolo della riunione**; i **nomi per i partecipanti** (elenco ordinato senza ripetizioni, da Teams e dagli invitati dell'evento); la **cronologia dei parlanti di Teams** (intervalli con inizio e fine in secondi dall'inizio della call e nome facoltativo). Restano sul Mac e se ne vanno con la call quando viene eliminata.
- All'avvio della registrazione la call prende come titolo della riunione il titolo della riunione mostrata da Teams, altrimenti il titolo dell'evento in corso (il più recente tra quelli in corso all'avvio) mentre il calendario è collegato; e come nomi per i partecipanti le persone mostrate da Teams e gli invitati di quell'evento.
- Titolo mostrato: quello dato dall'utente, altrimenti il titolo della riunione, altrimenti il titolo predefinito. Un titolo dato dall'utente vince sempre; un titolo digitato vuoto ripristina il titolo della riunione, altrimenti quello predefinito. Il titolo della riunione non va mai a omp.

## Nomi da Teams dopo la separazione
- Quando la separazione per voce finisce, con "Identifica i parlanti" acceso e una cronologia dei parlanti di Teams nella call: per ogni partecipante il tempo di ciascuna riga è diviso tra i nomi degli intervalli di Teams che la sovrappongono; il nome con più tempo vince se copre almeno il 70% del tempo totale delle righe del partecipante. Altrimenti resta "Partecipante N".
- Un nome va a un solo partecipante: se due vincono lo stesso nome, lo prende quello con la quota più alta e l'altro tiene il numero.
- Il nome è salvato come nome del partecipante, come se lo avesse scritto l'utente, quindi non va mai a omp. Un nome dato dall'utente non viene mai sostituito. Una separazione rifatta sostituisce i partecipanti e ridà i nomi con la stessa regola.
- Quando Teams non ha mostrato chi parla, nessun nome automatico viene dato.

## Rinomina dei partecipanti
- Nella pagina della call, cliccando il nome di un partecipante nella trascrizione, il campo di rinomina offre, mentre "Identifica i parlanti" è acceso, i nomi tenuti con la call da Teams e dal calendario che nessun altro partecipante della call ha già.

## Identifica i parlanti
- Interruttore "Identifica i parlanti", acceso di default e salvato tra gli avvii. `user.TURN_OFF_SPEAKER_IDENTIFICATION` lo spegne: nessun nome dato in automatico né suggerito, la finestra dal vivo mostra "Altri"; i nomi già dati restano. `user.TURN_ON_SPEAKER_IDENTIFICATION` lo riaccende e vale per le separazioni che finiscono dopo. Titoli delle call e proposta non ne dipendono.

## Code notes
Commit: 58d947126f08b8c7e4128d08782a627080bde977
- Naming: `Sources/LARP/Call/CallNaming.swift` `displayTitle`, `defaultTitle`, `normalizedName`, `Participant.displayName`.
- Dati: `Sources/LARP/Model/Call.swift`, `ArchiveStore.swift` `schema`, `delete`. Campi SwiftData nuovi con default così i vecchi archivi si aprono (vedi `summaryStateRawValue`).
- Inizio registrazione: `Sources/LARP/Call/CallLifecycle+Recording.swift` `recordingStarted`; `appendLiveLine` non salva.
- Separazione: `Sources/LARP/Call/CallLifecycle+Separation.swift` `finishSeparation` (dove applicare i nomi, prima che parta la sintesi); `Separation/ParticipantSeparator.swift`. Pitfall: una nuova separazione sostituisce i partecipanti e i loro nomi si perdono.
- Rinomina: `Sources/LARP/Call/CallLifecycle.swift` `renameCall`, `renameParticipant`; UI in `Sources/LARP/Archive/CallDetailView.swift` (alert di rinomina).
- Cosa riceve omp: `Refinement/RefinementRequest.swift` `RefinementLine.originalLines/json` e `Summary/SummaryRequest.swift`: non devono mai includere titolo della riunione o nomi.
- La sintesi tiene owner "Io"/"Partecipante N" e sostituisce i nomi solo in visualizzazione (`SummaryContent.replacingParticipants`).
- Chiave impostazione in `Sources/LARP/Settings/SettingsKey.swift`; Model work sul main actor; test di riferimento `CallRecordingTests`, `CallManagementTests`, `ArchiveStoreTests`.
