---
refs:
  - call
  - requirements/quality#call
---
# Crash alla cancellazione

Sul runner macOS di GitHub il processo dei test crasha a intermittenza con "Test crashed with signal trap", senza crash report nell'xcresult. Il crash è presente dalla CI di `v0.3.0` e ha fatto fallire anche la CI di `main` e il primo tentativo della release `v0.4.0`. Al momento del crash erano sempre in corso test che cancellano una call mentre un lavoro in background è ancora attivo: `CallRefinementTests.deleteStopsRefinement` ogni volta, e inoltre `CallTranscriptionTests.deletedWhileTranscribing`, `CallTranscriptionTests.failedThenDeleted`, `CallRecordingTests.languageNotReady`, `CallManagementTests.renameParticipantNeedsReady`, `CallManagementTests.renameParticipantOnlyInThisCall` e `TranscriptionLanguageTests.staleDownloadIsIgnored`. In locale tutti i test passano. L'ipotesi, da verificare, è che il lavoro in background (rifinitura, trascrizione o separazione delle voci) tocchi i dati SwiftData della call dopo che è stata cancellata: in quel caso potrebbe crashare anche l'app vera.

Il Model dice, per la Machine `call`, che `user.DELETE_CALL` porta a Deleted da ogni State: durante la trascrizione "the transcription stops and the audio and any partial transcript are deleted", durante la separazione "the separation stops and the audio and transcript are deleted", durante la rifinitura "the refinement stops and the audio and transcript are deleted".

A lavoro finito:

- La causa del crash è trovata e corretta nel codice dell'app, non nei test: cancellare una call mentre la sua trascrizione, la separazione dei partecipanti o la rifinitura lavorano in background non fa mai crashare l'app. Il lavoro in corso si ferma e, una volta cancellata la call, non legge e non scrive più quella call, le sue righe o i suoi partecipanti.
- Un test automatico cancella una call durante ciascuno di questi tre lavori in background e riproduce le condizioni del crash; passa a ogni esecuzione, sul runner della CI come sul Mac dello sviluppatore, ed è deterministico come vuole `requirements/quality#General`: aspetta l'effetto che verifica, mai un tempo fisso.
- I workflow non ripetono in automatico i test falliti (niente `-retry-tests-on-failure`): il crash si elimina nella causa, non si nasconde.
- L'intero test plan passa nella CI su GitHub.
