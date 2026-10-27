---
column: done
technical: true
refs:
  - specs#languages
  - specs#frameworks
  - specs#data
  - specs#deployment
  - specs#notes
  - requirements/tech#General
  - requirements/data#General
  - requirements/data#call
  - requirements/ui#General
  - requirements/quality#General
drift: null
proposal: dlpwzchv
agent: false
created: 2026-10-27T10:07:36.916Z
finished: 2026-10-27T10:11:33.156Z
---
# Scheletro progetto

Creare lo scheletro dell'app macOS LARP, su cui si appoggiano tutti gli altri Task.

Quando il Task è finito:
- Esiste un `project.yml` di XcodeGen (scelta dell'agente: progetto leggibile e versionato) che genera un progetto Xcode per un'app Swift 6 con concurrency stretta e SwiftUI, target minimo macOS 26.0, solo arm64 (Mac con Apple silicon, M1 e successivi). Il `.xcodeproj` generato è in `.gitignore`. Un `README.md` in inglese spiega come installare XcodeGen, generare il progetto, compilare ed eseguire.
- L'app è un'app della barra dei menu senza icona nel Dock (`LSUIElement`), con una scena `MenuBarExtra` (icona a microfono, menu con "Registra", "Apri archivio", "Impostazioni…", "Esci" ancora senza logica), una scena `Window` per l'archivio e una scena `Settings`, tutte vuote ma navigabili.
- L'app non è in sandbox ed è firmata solo per l'esecuzione locale (ad-hoc o team personale): nessuna notarizzazione, nessuna distribuzione (build locale con Xcode, decisione dello sviluppatore).
- L'Info.plist dichiara `NSMicrophoneUsageDescription` e `NSAudioCaptureUsageDescription` con testi in italiano che spiegano che l'audio delle call resta sul Mac.
- Le dipendenze passano solo da Swift Package Manager; l'unica di terze parti è FluidAudio (versione fissata), aggiunta ora anche se usata più avanti.
- Esiste il modello SwiftData dell'archivio, salvato in `~/Library/Application Support/LARP/`, come dicono i Requirements `data`: una call con identificativo, titolo opzionale, data e ora di inizio e fine, durata, nome dell'app di call (assente per le registrazioni manuali), lingua di trascrizione, stato corrente (Recording, Awaiting language, Transcribing, Separating participants, Awaiting separation retry, Ready), riferimenti ai due file audio `Recordings/<id call>/mic.caf` e `system.caf`; le righe di trascrizione (parlante: Io, Altri o un partecipante; inizio e fine relativi all'inizio della call; testo); i partecipanti (numero 1, 2, … e nome opzionale, appartengono a una sola call). Eliminare una call elimina anche righe, partecipanti e la cartella dei suoi audio.
- Le impostazioni (lingua di trascrizione, avvio all'accesso) hanno le loro chiavi in `UserDefaults`.
- Tutti i testi dell'interfaccia sono in italiano, con aspetto standard macOS che segue tema chiaro e scuro.
- Nessun servizio cloud, nessun account, nessuna telemetria: l'unico uso della rete previsto è il download dei modelli vocali Apple e dei modelli FluidAudio.
- Il progetto compila con `xcodebuild` e l'app si avvia mostrando l'icona nella barra dei menu.
