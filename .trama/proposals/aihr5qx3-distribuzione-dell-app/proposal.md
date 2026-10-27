---
status: approved
base:
  specs.yaml: 0e8a3d33c007ce8427253e79126685ce82d8fe86e82198e64395a2d376956b45
  requirements/tech/stack.md: 75b2f95f178a01feb495258c0b0140a3e9bac732319283d4710b00d2628d1a55
delete: []
created: 2026-10-27T12:06:58.331Z
label: Distribuzione
---
# Distribuzione dell'app

Oggi LARP si può usare solo compilandola in locale con Xcode: i Requirements escludono qualsiasi distribuzione e la CI compila e testa senza pubblicare nulla. Per installarla su altri Mac (dello sviluppatore e di poche persone di fiducia) serve un'app già pronta da scaricare.

## Decisioni
- Destinatari: i Mac dello sviluppatore e poche persone di fiducia, nessuna distribuzione pubblica.
- Accesso: le persone di fiducia sono collaboratori in sola lettura del repository privato `nicchia-code/LARP` e scaricano dalla pagina Releases.
- Firma: ad-hoc come oggi, nessuna notarizzazione; chi scarica toglie la quarantena a mano e macOS richiede i permessi a ogni aggiornamento.
- Canale: una GitHub Release a ogni tag `vX.Y.Z`, prodotta da GitHub Actions.
- Test: la Release viene pubblicata solo se i test passano.
- Versione: presa dal tag e scritta dalla CI (`v1.2.0` → 1.2.0), numero di build dal numero dell'esecuzione; `project.yml` non si tocca per rilasciare.
- Formato: DMG semplice creato con `hdiutil`, con `LARP.app` e un collegamento ad Applicazioni.
- Aggiornamenti: a mano, scaricando la nuova versione; l'app non controlla aggiornamenti.
- Istruzioni di installazione: nel testo della Release in italiano, seguito dalle note generate da GitHub, e nel README in inglese.

## Assunzioni dell'agente
- Il rilascio è un workflow separato da quello di CI, attivato solo dai tag `v*`.
- L'app pubblicata usa la configurazione Release; il DMG si chiama `LARP-<versione>.dmg` e la Release prende il nome del tag.
- Il README documenta anche come pubblicare una versione (push di un tag `vX.Y.Z`).
