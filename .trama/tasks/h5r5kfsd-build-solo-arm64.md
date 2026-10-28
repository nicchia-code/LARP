---
column: done
technical: true
refs:
  - requirements/tech#General
drift: null
proposal: nadw5tav
agent: false
created: 2026-10-28T17:34:34.658Z
finished: 2026-10-28T17:37:32.687Z
---
# Build solo arm64

La release `v0.4.0` non è stata pubblicata: nel passo "Build Release" di `.github/workflows/release.yml` i pacchetti Swift Package Manager (WebRTCAudioProcessing, Abseil) vengono compilati anche per `x86_64`, perché in Release `ONLY_ACTIVE_ARCH` è `NO` e `ARCHS: arm64` di `project.yml` vale solo per il target LARP. WebRTCAudioProcessing contiene solo i sorgenti ARM, quindi la compilazione si ferma con `<arm_neon.h> is intended only for ARM and AArch64 targets` (per esempio su `vad_wrapper.cc`). In locale, aggiungendo `ARCHS=arm64` al comando `xcodebuild build` del workflow, la build Release riesce e l'app contiene solo arm64. In `project.yml` c'è anche `EXCLUDE_ARCHS: x86_64`, che non ha effetto perché il nome dell'impostazione è `EXCLUDED_ARCHS`.

A lavoro finito:

- Ogni target, dipendenze Swift Package Manager incluse, è compilato solo per arm64, sia in Debug sia in Release: in locale, nella CI (`ci.yml`) e nel workflow di release. L'impostazione sbagliata `EXCLUDE_ARCHS` di `project.yml` è corretta o tolta, così che nessuna impostazione inefficace resti nel progetto.
- Il workflow di release, dopo la build e prima di creare il DMG, controlla che l'eseguibile di `LARP.app` contenga solo l'architettura arm64 (per esempio con `lipo -archs`), insieme ai controlli già presenti su versione, numero di build e firma; se il controllo fallisce il workflow si ferma e non pubblica niente.
- La build Release in locale, con lo stesso comando `xcodebuild build` del workflow, riesce e produce un'app solo arm64 che passa `codesign --verify --deep --strict`.
- Il README, nella parte sulla pubblicazione delle release, dice in inglese che un tag `vX.Y.Z` già pushato non si sposta, non si cancella e non si ricrea, nemmeno quando il suo workflow di release è fallito: la correzione esce con la versione patch successiva (per esempio `v1.2.1` dopo un `v1.2.0` fallito).
- `project.yml` non viene modificato per indicare la versione: la versione continua a venire dal tag.

Il tag `v0.4.0` già pushato resta com'è, senza Release; la correzione verrà rilasciata come `v0.4.1`, ma creare quel tag non fa parte di questa Task.
