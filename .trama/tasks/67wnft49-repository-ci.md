---
column: doing
technical: true
refs:
  - specs#repository
  - specs#ci
  - specs#testing
drift: null
proposal: dlpwzchv
agent: hf4j40
created: 2026-10-27T10:07:36.916Z
---
# Repository e CI

Mettere il progetto sotto git, pubblicarlo su GitHub e attivare la CI (decisioni dello sviluppatore: repository su GitHub, test con Swift Testing, CI con GitHub Actions).

Quando il Task è finito:
- La cartella del progetto è un repository git con un `.gitignore` per Xcode/Swift (build, DerivedData, `.xcodeproj` generato, file utente) che non esclude `.trama/`.
- Il repository esiste su GitHub (privato salvo diversa indicazione dello sviluppatore) e il ramo principale è pubblicato. Se la `gh` CLI non è autenticata, il Task si ferma chiedendo allo sviluppatore di farlo, senza inventare credenziali.
- Esiste un target di test con Swift Testing e almeno un test reale della logica pura già presente (per esempio il modello SwiftData in memoria).
- Un workflow GitHub Actions gira a ogni push e pull request su un runner `macos-26` (scelta dell'agente: immagine GitHub con Xcode per macOS 26): installa XcodeGen, genera il progetto, compila ed esegue i test. I test che richiedono modelli vocali Apple, modelli FluidAudio, microfono o audio di sistema sono marcati in modo da non girare in CI.
- Il workflow passa sul ramo principale.
