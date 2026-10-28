---
status: approved
base:
  requirements/quality/main.md: 7f5fe296e55461432190f7291d98924eccf40daa7fe7bdc4cb4fe557347588cd
delete: []
created: 2026-10-27T17:18:57.702Z
label: Test stabili
---
# Test stabili sul download

Il workflow di release della v0.2.0 è fallito al primo tentativo per due test instabili, `TranscriptionLanguageTests.launchNotInstalledDownloads` e `chooseNotInstalledDownloads`, mentre la CI sullo stesso commit era passata. I test aspettano che la lingua sia "Download in corso" e subito dopo controllano che il download sia partito, ma `TranscriptionLanguageController` imposta lo stato prima di chiamare `install`: su un runner lento il controllo arriva troppo presto. Questa Proposal rende stabili i test e scrive la regola che lo evita in futuro.

## Decisioni
- Si correggono solo i test; il codice dell'app non cambia.
- Si correggono tutti i test con lo stesso schema (attesa di uno stato intermedio seguita dal controllo di un effetto che arriva dopo), non solo i due che sono falliti.
- Si aggiunge un requisito di qualità: i test aspettano l'effetto che controllano, mai uno stato intermedio o un tempo fisso.
