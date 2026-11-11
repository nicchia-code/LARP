---
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
---
# Lettura di Teams

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
