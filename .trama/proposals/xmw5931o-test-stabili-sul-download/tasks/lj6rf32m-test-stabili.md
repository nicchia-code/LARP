---
technical: true
refs:
  - requirements/quality#General
---
# Test stabili sul download

Quando il lavoro è finito, i test aspettano l'effetto che controllano, mai uno stato intermedio che lo precede e mai un tempo fisso. Il codice dell'app non cambia: si toccano solo i test.

**Causa.** Due test di `Tests/LARPTests/TranscriptionLanguageTests.swift` sono instabili: `launchNotInstalledDownloads` ("launch without the model goes to Downloading, then Ready when installed") e `chooseNotInstalledDownloads` ("choosing a language that is not installed starts its download").
- Aspettano `controller.status == .downloading` e subito dopo controllano `models.installCalls`.
- `TranscriptionLanguageController.run` però imposta `status = .downloading` prima di chiamare `models.install(code)`, e la chiamata registrata dal fake arriva dopo.
- Su un runner lento il controllo arriva troppo presto: il workflow di release della v0.2.0 è fallito con `(models.installCalls → []) == ["it-IT"]` e `== ["en-US"]`, mentre la CI sullo stesso commit era passata.

**Correzione.** In quei due test si aspetta anche che il download sia davvero partito, per esempio `installCalls` non vuoto o un segnale del fake al suo ingresso in `install`, prima di controllare quali download sono partiti. Il resto di ciò che i test verificano resta uguale.

**Stesso schema altrove.** Vanno controllati tutti i test in `Tests/LARPTests/`, non solo questi due. Ogni test che aspetta uno stato intermedio e poi controlla un effetto che arriva dopo si corregge allo stesso modo, e lo stesso vale per un test che conta su un'attesa di durata fissa. Gli `waitUntil` usati come attesa con limite massimo vanno bene, purché la condizione sia l'effetto controllato.

**Verifica.** La suite completa (`xcodebuild test` con il test plan di `Tests/LARP.xctestplan`) passa. I due test corretti passano anche ripetuti molte volte, per esempio con `-test-iterations 50 -run-tests-until-failure` su `-only-testing:LARPTests/TranscriptionLanguageTests`.
