---
status: approved
base:
  requirements/tech/stack.md: 0c2b4696927e6844d8137c9e19caf3eb319d03fef2f1d9ea1d9678401c010f3c
  requirements/quality/main.md: 5720c344d3a0007d7b801db467d180c32021b4001e2f88498b7c548189cd4dc6
delete: []
created: 2026-10-28T17:24:13.029Z
label: Release arm64
---
# Release solo arm64

La release `v0.4.0` non è stata pubblicata. In Release i pacchetti Swift (WebRTC, Abseil) vengono compilati anche per `x86_64`, e WebRTC contiene solo sorgenti ARM: la build si ferma su `<arm_neon.h> is intended only for ARM and AArch64 targets`. Il requisito "solo arm64" oggi vale solo per il target dell'app. In più, un crash intermittente ("signal trap") del processo di test sul runner di GitHub, presente da `v0.3.0`, fa fallire CI e release. Ogni volta era in corso un test che cancella una call mentre la trascrizione o la rifinitura lavorano in background, e lo stesso può succedere nell'app vera.

## Decisioni
- Una sola Proposal per la build e per il crash, con due Task.
- Ogni target, pacchetti Swift inclusi, è compilato solo per arm64 in Debug e in Release.
- Il workflow di release verifica che l'app costruita contenga solo arm64 prima di creare il DMG.
- Un tag `vX.Y.Z` già pushato non viene mai spostato né ricreato, anche se la sua Release non è stata pubblicata: la correzione esce con la patch successiva (questa volta `v0.4.1`).
- Il crash si corregge nella causa, nel codice dell'app, con un test di regressione che cancella una call durante il lavoro in background; i test falliti non vengono ripetuti in automatico.
