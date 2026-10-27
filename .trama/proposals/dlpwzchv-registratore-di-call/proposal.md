---
status: approved
kind: setup
base:
  system.md: a3a88d801ab8d3690d5b9a960e96f724655a2ed0d109f6b63beda0b094fc7b6d
  actors/user.md: new
  actors/macos.md: new
  capture/feature.md: new
  capture/recorder.md: new
  transcription/feature.md: new
  transcription/call.md: new
  settings/feature.md: new
  settings/transcription-language.md: new
  library/feature.md: new
  library/main-window.md: new
  library/playback.md: new
  requirements/tech/stack.md: new
  requirements/data/storage.md: new
  requirements/rules/behaviour.md: new
  requirements/ui/screens.md: new
  requirements/quality/main.md: new
  specs.yaml: new
delete: []
request: 2026-10-27T10-41-54
created: 2026-10-27T10:04:17.500Z
label: LARP
---
# Registratore di call

# Registratore di call LARP

App macOS per Mac con Apple silicon (M1) che registra le call e le trascrive on-device con le API di Apple, separando poi i singoli partecipanti. La richiesta chiedeva di usare le funzioni AI del Mac: l'embedder di Apple (`NLEmbedding`) lavora solo su testo, quindi la trascrizione usa `SpeechTranscriber`, verificato su questo Mac per italiano (it-IT, scaricabile) e inglese (installato). Nessuna alternativa esterna è servita.

## Decisioni
- Motore di trascrizione: Apple SpeechAnalyzer / SpeechTranscriber, on-device.
- Audio registrato: microfono + audio di sistema, come due tracce separate.
- Avvio: proposta automatica quando un'app di call nota inizia a usare il microfono; avvio manuale sempre possibile dalla barra dei menu.
- Proposta ignorata: sparisce quando l'app di call rilascia il microfono, niente viene registrato.
- Fine: la registrazione partita da una proposta si ferma da sola quando l'app di call rilascia il microfono; stop manuale sempre possibile. Quella avviata a mano si ferma solo a mano.
- Trascrizione in diretta in background, senza vista in diretta: il testo si legge a fine call.
- Lingua: una sola, scelta nelle impostazioni (italiano o inglese).
- Lingua non ancora installata all'avvio di una registrazione: si registra comunque e si trascrive dal file appena la lingua è pronta.
- Chi parla: microfono = "Io", audio di sistema = "Altri" in diretta; a fine call separazione per singolo partecipante con FluidAudio on-device (impronte vocali + raggruppamento); nessun LLM di correzione per ora.
- Partecipanti: "Partecipante 1, 2…", rinominabili per singola call.
- Separazione fallita: la trascrizione resta con "Io"/"Altri" e la separazione si riprova da sola (al ritorno della rete o al riavvio dell'app).
- Forma: icona nella barra dei menu + finestra con l'archivio.
- Nessuna altra funzione AI per ora (niente riassunti né ricerca semantica).
- Si conservano audio e trascrizione, in un archivio interno (SwiftData nella cartella di supporto dell'app).
- Archivio: ricerca per parola, riascolto sincronizzato, rinomina call, elimina call. Esportazione in Markdown.
- Permesso mancante (microfono o audio di sistema): non si registra e si avvisa come concederlo.
- Chiusura dell'app o spegnimento durante una registrazione: alla riapertura la call viene chiusa e trascritta fin dove arriva l'audio salvato.
- Avvio all'accesso: attivabile nelle impostazioni, disattivato di base.
- macOS 26 minimo, Swift + SwiftUI, build locale con Xcode (nessuna distribuzione firmata), repository su GitHub, Swift Testing + GitHub Actions.

## Scelte dell'agente (da verificare)
- Cattura dell'audio di sistema con i Core Audio process tap (permesso "solo audio di sistema", senza registrazione schermo).
- Progetto Xcode generato con XcodeGen da un `project.yml` versionato.
- Runner CI `macos-26`; i test che richiedono i modelli vocali non girano in CI.
- Audio salvato in CAF/AAC, leggibile anche se la scrittura si interrompe.
- Lingua predefinita al primo avvio: italiano; inglese = en-US.
- Interfaccia in italiano.
- App di call note: Zoom, Microsoft Teams, FaceTime, Slack, Discord, Webex e i browser principali (per Meet e simili).
- La proposta compare in un piccolo pannello sotto l'icona della barra dei menu.
- Nessun cloud e nessun file di infrastruttura: tutto gira sul Mac.
