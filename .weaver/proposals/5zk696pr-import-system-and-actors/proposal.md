---
status: approved
kind: import
base:
  model/actors/assistant.md: new
  model/actors/macos.md: new
  model/actors/time.md: new
  model/actors/user.md: new
  model/system.md: b93fab3a9684d9396cf3eaa11e68ef1fcda0e2320ec5ee14e8299d4003752eeb
  requirements/data/general.md: new
  requirements/tech/general.md: new
  specs.yaml: new
created: 2026-11-11T12:32:27.629Z
label: Import
job: a8nt702p
---
# Import: System and Actors

Importa il System LARP dal codice del repository: le cartelle `Sources/LARP`, `Tests/LARPTests`, `Packages/WebRTCAudioProcessing` (solo il wrapper, non la copia di WebRTC), `Config`, `.github/workflows`, `project.yml` e il README. Descrive il System, gli Actor che emettono Event (utente, macOS, omp), i Requirement generali di `tech` e `data` e le Specs dedotte dai manifest.

Decisioni dello sviluppatore: quattro Feature (`capture`, `transcription`, `library`, `settings`); la cartella `.trama/` è usata solo come riferimento per i nomi, non come documentazione da confrontare.

Gli Actor sono quattro: l'utente, macOS, omp (l'assistente) e il tempo (l'attesa prima di ritentare una trascrizione).

## Doubts

- `Packages/WebRTCAudioProcessing/Package.resolved` fissa Abseil alla versione 0.20240722.2, mentre `Package.swift` chiede esattamente 0.20250127.1 e il README del pacchetto spiega che la release 20240722 non compila con WebRTC: il file di lock sembra rimasto indietro (quando il pacchetto è usato come dipendenza locale Xcode usa il lock del progetto generato, quindi l'effetto pratico non è stato determinato).
