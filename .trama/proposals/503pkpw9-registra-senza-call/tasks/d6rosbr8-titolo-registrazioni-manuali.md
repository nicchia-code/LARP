---
technical: false
refs:
  - call
  - requirements/rules#call
---

# Titolo registrazioni manuali

Una call nasce quando il recorder avvia una registrazione. Ora la registrazione può partire anche a mano da Idle, senza alcuna call app: in quel caso la call non ha il nome della call app (`Call.callAppName` è `nil`).

Quando è finito deve valere il requisito: "A call without a title is shown as \"Call del <day> <month> <year>, <hh:mm>\" when it is tied to a call app, and as \"Registrazione del <day> <month> <year>, <hh:mm>\" when it has no call app (started by hand), with the Italian month name, for example \"Call del 27 ottobre 2026, 10:41\" and \"Registrazione del 28 ottobre 2026, 15:35\"."

Quindi il titolo predefinito (oggi costruito da `defaultTitle` e restituito da `displayTitle` in `Sources/LARP/Call/CallNaming.swift`) dipende dalla presenza della call app: con call app resta "Call del …", senza call app diventa "Registrazione del …", con lo stesso formato di data e ora e il nome del mese in italiano. Le call rilevate da una call app, anche quelle già in archivio, continuano a chiamarsi "Call del …".

Il titolo predefinito giusto deve comparire ovunque compare il titolo: nella lista dell'archivio (`CallRow`), nel dettaglio della call (`CallDetailView`), nella ricerca, che deve trovare la call anche per il titolo predefinito ("Registrazione" compreso, `CallSearch`), e nel nome file predefinito dell'esportazione, che è il titolo della call (`TranscriptExport`).

Resta valido "An empty title or empty name given by the user restores the default": se l'utente svuota il titolo di una registrazione senza call app torna "Registrazione del …", se lo svuota per una call con call app torna "Call del …". Un titolo dato dall'utente continua ad avere la precedenza sul predefinito in tutti i punti sopra.
