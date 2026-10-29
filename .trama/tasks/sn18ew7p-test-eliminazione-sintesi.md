---
column: done
technical: true
refs:
  - requirements/quality#call
drift: null
proposal: 15u4f1ps
agent: false
created: 2026-10-28T19:23:51.370Z
finished: 2026-10-28T19:34:16.295Z
---
# Eliminare durante i lavori

Eliminare una chiamata mentre in background girano la trascrizione, la separazione dei partecipanti, la rifinitura o la sintesi non fa mai crashare l'app: il lavoro in corso si ferma e, una volta eliminata la chiamata, non legge né scrive mai più la chiamata, le sue righe, i suoi partecipanti o la sua sintesi.

Un test automatico (in Tests/LARPTests, accanto a CallRefinementTests.swift, con un fake di sintesi in CallLifecycleFakes.swift) elimina una chiamata per ognuno di questi lavori, sintesi compresa: avvia la sintesi con un fake che resta in attesa, elimina la chiamata con `deleteCall(_:)`, poi fa rispondere il fake e verifica che il processo sia stato terminato e che nulla venga salvato. Il test aspetta l'effetto che verifica, mai un tempo fisso né uno stato intermedio, e passa a ogni esecuzione, sul runner CI come sul Mac dello sviluppatore.
