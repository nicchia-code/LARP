---
refs:
- calendar-access
- requirements/rules#calendar-access
- requirements/tech#calendar-access
- user.CONNECT_CALENDAR
- user.DISCONNECT_CALENDAR
---
# Calendario del Mac

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
