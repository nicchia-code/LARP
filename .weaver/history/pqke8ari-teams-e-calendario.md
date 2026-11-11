---
created: 2026-11-11T16:47:20.701Z
updated: 2026-11-11T16:47:20.701Z
summary: Lettura di Teams e del calendario per titoli, partecipanti e proposta di registrazione.
tasks:
- 86bmwhzc
- nbxzusub
- c8bln45q
- uinm76oo
cleared:
  86bmwhzc:
    title: Titoli e nomi dalle riunioni
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
    technical: false
    proposal: 974kl54q
    label: 'Redesign: Teams e calendario'
    finished: 2026-11-11T16:23:17.556Z
    body: |-
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
  c8bln45q:
    title: Lettura di Teams
    refs:
    - teams-access
    - teams-meeting
    - teams
    - meeting-info
    - time.ACCESSIBILITY_CHECK_DUE
    - requirements/rules#teams-meeting
    - requirements/tech#teams-access
    - requirements/tech#teams-meeting
    - requirements/quality#General
    - specs#frameworks
    - user.ALLOW_TEAMS_ACCESS
    technical: false
    proposal: 974kl54q
    label: 'Redesign: Teams e calendario'
    finished: 2026-11-11T16:35:37.788Z
    body: |-
      LARP legge Microsoft Teams tramite l'Accessibilità di macOS, solo quando l'utente lo consente, e ne ricava la riunione mostrata: titolo, persone e chi sta parlando. Quando il lavoro è finito valgono le condizioni seguenti.

      ## Accesso a Teams
      - Il permesso Accessibilità viene letto all'avvio, all'apertura delle Impostazioni e, dopo "Consenti", ogni 2 secondi per 2 minuti (`time.ACCESSIBILITY_CHECK_DUE`), perché macOS non avvisa quando lo concede o lo toglie.
      - Da "Non consentito", `user.ALLOW_TEAMS_ACCESS` fa chiedere a macOS il permesso e apre Impostazioni di Sistema › Privacy e sicurezza › Accessibilità; lo stato passa a "In attesa del permesso". Da lì diventa "Consentito" appena il permesso c'è, resta in attesa finché mancano meno di due minuti dalla richiesta, torna a "Non consentito" dopo due minuti senza permesso; anche l'apertura delle Impostazioni lo porta a "Consentito" se il permesso c'è.
      - Da "Consentito", all'avvio o all'apertura delle Impostazioni, se il permesso manca (per esempio dopo una nuova versione) lo stato torna a "Non consentito", la lettura di Teams si ferma ed è emesso ACCESS_LOST.
      - La firma ad-hoc resta com'è: dopo ogni aggiornamento di LARP il permesso va concesso di nuovo; viene ricordato, nelle impostazioni salvate, che il permesso è stato visto concesso almeno una volta, così che la perdita dopo un aggiornamento si possa riconoscere e segnalare (la segnalazione nell'interfaccia è di un'altra Task). Lo stato del permesso stesso è tenuto solo in memoria.

      ## Riunione di Teams
      - Si legge solo il processo principale del nuovo Teams (`com.microsoft.teams2`), non il Teams classico, e solo mentre l'accesso è consentito e Teams è in esecuzione; l'avvio e la chiusura di Teams vengono seguiti.
      - Teams è in riunione mentre una sua finestra contiene l'elemento con identificatore web `call-duration-custom`; titoli di finestra e testi di Teams non servono mai a deciderlo, perché cambiano con la lingua.
      - Il titolo della riunione è il titolo di quella finestra senza la coda " | Microsoft Teams"; un titolo vuoto o uguale al nome di una sezione di Teams vale come nessun titolo.
      - Le persone si leggono dall'elenco dei partecipanti quando Teams lo mostra; chi parla dal segno che Teams mette su chi parla, quando Teams lo espone (lettura sperimentale: quando Teams non lo mostra, non c'è nessun parlante). Un nome è tenuto senza spazi attorno e senza le aggiunte come "(Ospite)" o "(Guest)"; il nome dell'utente stesso ("tu") è escluso.
      - Teams si legge ogni 2 secondi e a ogni cambiamento annunciato da Teams, al più una volta ogni 250 ms; quando una lettura non trova alcun elemento, LARP chiede a Teams di esporre la sua interfaccia alle app assistive e rilegge.
      - Stati: da "Nessuna riunione", MEETING_JOINED porta a "In riunione" (solo con accesso consentito), tenendo il titolo quando leggibile; durante una registrazione la call in corso lo prende come titolo della riunione se non ne ha già uno. PARTICIPANTS_READ sostituisce le persone note e, durante una registrazione, aggiunge ai nomi per i partecipanti della call i nomi non già tenuti. SPEAKER_CHANGED cambia chi parla (o nessuno) e, durante una registrazione non in pausa, aggiunge il cambio alla cronologia dei parlanti della call al tempo trascorso. MEETING_LEFT e ACCESS_LOST riportano a "Nessuna riunione" dimenticando titolo, persone e parlante; ciò che è già tenuto con una call resta.
      - La cronologia dei parlanti ha un intervallo per cambio, con inizio e fine in tempo trascorso e il nome, o nessun nome quando nessuno è segnato; gli intervalli sotto i 300 ms sono scartati.
      - Ogni Event di Teams può non arrivare mai: l'app deve funzionare comunque senza di esso.

      ## Privacy
      - Ciò che si legge da Teams resta sul Mac, è tenuto solo con la call a cui appartiene e non va mai a omp né nei log. Teams si legge solo con il permesso e quando serve.

      ## Code notes
      Commit: 58d947126f08b8c7e4128d08782a627080bde977
      - Nuovo codice in una cartella propria sotto `Sources/LARP/` (presa senza toccare `project.yml`, poi `xcodegen generate`).
      - Requisiti tecnici: `AXIsProcessTrusted`; "Consenti" → `AXIsProcessTrustedWithOptions` con prompt e apertura di `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`. `AXUIElement` dell'app trovata con `NSRunningApplication` (bundle `com.microsoft.teams2`), visita delle finestre con limite 25.000 nodi e uscita al primo marcatore `AXDOMIdentifier` = `call-duration-custom`; `AXObserver` (finestra, titolo, layout, distrutto) sul main run loop; timer 2 s come base. Se nessun `AXDOMIdentifier`: impostare `AXManualAccessibility` e `AXEnhancedUserInterface` sull'elemento app (le chiamate restituiscono errore ma funzionano), poi rileggere. Titolo finestra con suffisso ` | Microsoft Teams`.
      - Letture fuori dal main actor, risultati consegnati al main actor; avvio/chiusura Teams via notifiche di `NSWorkspace`.
      - Lettura dietro un protocollo con un Teams finto nei test (fake in `Tests/LARPTests/CallLifecycleFakes.swift` come modello).
      - Il permesso è legato alla firma: le build ad-hoc lo perdono a ogni versione.
      - Ogni Machine è una tabella pura `target(from:on:)`, gli eventi portano i fatti di guardia; i commenti citano gli Event del Model.
      - Chiavi in `Sources/LARP/Settings/SettingsKey.swift`; `UserDefaults` iniettato, suite isolate nei test.
      - Campi nuovi della call (SwiftData) con default, vedi `summaryStateRawValue`; dati in `Sources/LARP/Model/Call.swift`; inizio registrazione in `CallLifecycle+Recording.swift` `recordingStarted`.
  nbxzusub:
    title: Calendario del Mac
    refs:
    - calendar-access
    - requirements/rules#calendar-access
    - requirements/tech#calendar-access
    - user.CONNECT_CALENDAR
    - user.DISCONNECT_CALENDAR
    technical: false
    proposal: 974kl54q
    label: 'Redesign: Teams e calendario'
    finished: 2026-11-11T16:21:17.315Z
    body: |-
      LARP legge il calendario del Mac, solo mentre è collegato e macOS concede l'accesso completo agli eventi: l'evento in corso quando parte una registrazione (titolo e invitati) e gli eventi del resto della giornata per "Prossime". Quando il lavoro è finito valgono le condizioni seguenti.

      ## Accesso al calendario
      - "Non collegato" (iniziale, salvo che il calendario fosse già collegato): il calendario non si legge. `user.CONNECT_CALENDAR` porta a "Collegato" quando macOS concede l'accesso completo, chiesto all'utente la prima volta, e la scelta è salvata; porta a "Rifiutato" quando l'utente rifiuta, o aveva già rifiutato: le impostazioni dicono che l'accesso è negato e offrono di aprire il pannello Calendari di Impostazioni di Sistema.
      - "Collegato": il calendario si legge. `user.DISCONNECT_CALENDAR` porta a "Non collegato", salva la scelta e smette subito ogni lettura; il permesso di macOS resta com'è (si toglie da Impostazioni di Sistema). All'avvio o all'apertura delle Impostazioni, se macOS non concede più l'accesso, si passa a "Rifiutato".
      - "Rifiutato": l'utente vuole il calendario ma macOS non lo concede. `user.CONNECT_CALENDAR` apre il pannello Calendari di Impostazioni di Sistema; all'avvio o all'apertura delle Impostazioni si passa a "Collegato" se ora l'accesso c'è; `user.DISCONNECT_CALENDAR` porta a "Non collegato" e salva la scelta.
      - La scelta di collegare è salvata nelle impostazioni ("calendario collegato", sì/no, default no); lo stato dell'accesso concesso da macOS è tenuto solo in memoria.
      - L'app dichiara a macOS il motivo della richiesta di accesso completo agli eventi, in italiano, con il testo inglese nel catalogo delle stringhe.

      ## Letture
      - Si leggono tutti i calendari degli eventi del Mac.
      - **Evento in corso** all'avvio di una registrazione: tra gli eventi non di tutto il giorno iniziati in quel momento o prima e che finiscono dopo, quello iniziato per ultimo; se nessuno, nessun evento.
      - **Prossime**: gli eventi di oggi non di tutto il giorno, che iniziano dopo adesso e contengono nell'URL, nel luogo o nelle note il link di un'app di call nota: `teams.microsoft.com` o `teams.live.com` (Microsoft Teams), `zoom.us` (Zoom), `meet.google.com` (Google Meet), `webex.com` (Webex), `facetime.apple.com` (FaceTime); al massimo tre, per inizio, ciascuno con ora, titolo e nome dell'app; riletti quando si apre la finestra a comparsa.
      - Gli invitati di un evento sono i partecipanti con un nome, senza l'utente; il loro numero mostrato nella proposta conta anche l'utente.
      - I dati del calendario restano sul Mac e non vanno mai a omp.

      ## Code notes
      Commit: 58d947126f08b8c7e4128d08782a627080bde977
      - EventKit: un solo `EKEventStore`, `requestFullAccessToEvents` per collegare, `authorizationStatus(for: .event)` per leggere l'accesso, predicati sugli eventi di oggi per "Prossime" e per l'evento in corso.
      - Oggi in `project.yml` manca `NSCalendarsFullAccessUsageDescription`: aggiungerla in `info.properties` di `project.yml`, mai in `Config/Info.plist` (rigenerato); testo inglese nel String Catalog dell'Info.plist.
      - Il calendario sta dietro un protocollo con un calendario finto nei test (panel e permessi sono già dietro protocolli, `tech/general.md:15`).
      - Riconoscimento delle app di call: `Sources/LARP/Capture/KnownCallApps.swift` `KnownCallApps.all` (nomi delle app).
      - Chiave in `Sources/LARP/Settings/SettingsKey.swift`; `UserDefaults` iniettato, suite isolate e `.serialized` nei test.
      - Macchina come tabella pura `target(from:on:)`; i commenti citano gli Event del Model (`user.CONNECT_CALENDAR`).
      - App `LSUIElement`: aprire Impostazioni di Sistema non richiede altro, ma per le finestre serve `NSApp.activate()`.
      - Wiring in `Sources/LARP/App/LARPApp.swift` `init`.
  uinm76oo:
    title: Teams in proposta e live
    refs:
    - recorder
    - recording-view
    - onboarding
    - settings
    - requirements/ui#recorder
    - requirements/ui#onboarding
    - requirements/ui#settings
    - requirements/data#settings
    technical: false
    proposal: 974kl54q
    label: 'Redesign: Teams e calendario'
    finished: 2026-11-11T16:31:04.163Z
    body: |-
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
---
# Teams e calendario

Accesso Accessibilità a Teams, permesso del calendario, titoli e nomi dalle riunioni, nomi dei parlanti, riunione nella proposta e nella finestra dal vivo.
