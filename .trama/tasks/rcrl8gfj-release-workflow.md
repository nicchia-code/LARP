---
column: done
technical: true
refs:
  - requirements/tech#General
  - specs#ci
  - specs#repository
  - specs#deployment
drift: null
proposal: aihr5qx3
agent: false
created: 2026-10-27T12:09:42.777Z
finished: 2026-10-27T12:11:28.612Z
---
# Workflow di rilascio

Al termine esiste un workflow GitHub Actions di rilascio, separato da `.github/workflows/ci.yml` (che resta com'è), che a ogni push di un tag `vX.Y.Z` pubblica LARP come GitHub Release del repository privato `nicchia-code/LARP`.

Il workflow, su un runner `macos-26`:
- installa XcodeGen e genera il progetto, come la CI;
- esegue il test plan come la CI (`xcodebuild test`, con i test `.requiresHardware` saltati dal piano) e si ferma senza pubblicare nulla se un test fallisce;
- compila la configurazione Release con firma ad-hoc e senza notarizzazione, impostando in fase di build `MARKETING_VERSION` al tag senza la `v` iniziale (`v1.2.0` → `1.2.0`) e `CURRENT_PROJECT_VERSION` al numero dell'esecuzione del workflow; `project.yml` non viene modificato;
- crea con `hdiutil` un DMG semplice, `LARP-<versione>.dmg`, che contiene `LARP.app` e un collegamento a `/Applications`, senza immagine di sfondo né disposizione personalizzata;
- crea una GitHub Release con il nome del tag e il DMG allegato. Il testo della Release è in italiano e spiega come installare l'app (trascinare `LARP.app` in Applicazioni), come aprirla pur non essendo notarizzata (`xattr -dr com.apple.quarantine /Applications/LARP.app`, oppure "Apri comunque" in Impostazioni di Sistema → Privacy e sicurezza) e che macOS chiede di nuovo i permessi di microfono e audio di sistema dopo ogni aggiornamento; seguono le note di rilascio generate da GitHub.

La distribuzione resta limitata ai Mac dello sviluppatore e a poche persone di fiducia, collaboratori in sola lettura del repository: nessun canale pubblico. Gli aggiornamenti sono manuali: l'app non controlla aggiornamenti e non contatta nessun servizio di aggiornamento, quindi nell'app non cambia nulla.

Il README (in inglese) documenta come pubblicare una versione (push di un tag `vX.Y.Z`) e come installare e aprire l'app scaricata, con gli stessi passi del testo della Release; la frase che oggi descrive la firma come "local execution only (ad-hoc, no notarization, no distribution)" va aggiornata.

Verifica: il push di un tag di prova produce una Release con `LARP-<versione>.dmg`; il DMG montato mostra `LARP.app` e il collegamento ad Applicazioni; l'app copiata, tolta la quarantena, si avvia, e il suo `Info.plist` riporta in `CFBundleShortVersionString` la versione del tag e in `CFBundleVersion` il numero dell'esecuzione.
