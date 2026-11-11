---
created: 2026-11-11T13:27:42.562Z
updated: 2026-11-11T13:27:42.562Z
summary: 'Commenti del codice e README corretti perché descrivano il comportamento reale: rifinitura, limiti di omp, ritorno della rete, clic su una riga, avviso dell''eco, cartelle e archivio.'
tasks:
- 88m7l084
- tgd5lphx
- 0v9dfuam
- bbsx5rpf
- bh3p4hew
- e15ygp01
cleared:
  0v9dfuam:
    title: 'Fix the code: Commento sul ritorno della rete'
    refs:
    - macos.NETWORK_AVAILABLE
    technical: false
    finished: 2026-11-11T13:23:19.250Z
    body: |-
      ## What happens

      Quando la rete torna, oltre a ritentare il **download della lingua** e la **separazione dei partecipanti**, l'app ritenta anche la **rifinitura** delle chiamate in attesa e la **sintesi** delle chiamate in attesa di ritentarla.

      ## What should happen

      Il commento del monitor di rete condiviso dice che lo ascoltano solo le impostazioni (download della lingua) e la macchina della chiamata per **ritentare la separazione**: non nomina la rifinitura né la sintesi.

      ## Chosen option

      ### Correggere il commento

      Elencare nel commento tutti i lavori ritentati al ritorno della rete: download della lingua, separazione, rifinitura e sintesi. Nessun cambio di comportamento.

      ## Where in the code

      Sources/LARP/Settings/NetworkMonitor.swift; Sources/LARP/Call/CallLifecycle+Separation.swift; Sources/LARP/App/LARPApp.swift
  bbsx5rpf:
    title: 'Fix the code: README: cartelle e archivio'
    refs:
    - requirements/tech#General
    - requirements/data#General
    technical: true
    finished: 2026-11-11T13:23:30.843Z
    body: |-
      ## What happens

      Il codice è diviso in molte cartelle per area: la **finestra archivio** ha una cartella sua (archivio, riproduzione, chiamata, cattura, registrazione, trascrizione, separazione, assistente, rifinitura, sintesi, impostazioni, modello, app).

      L'archivio tiene **quattro** tipi di record: chiamate, righe di trascrizione, partecipanti e **sintesi**. Nella cartella dell'app in Application Support c'è anche la cartella **`Models/`** con i modelli per separare le voci, scaricati al primo uso.

      ## What should happen

      La sezione *Layout* del README dice che la cartella dell'app contiene anche la **finestra archivio** e che il modello conserva solo chiamate, righe e partecipanti, senza le **sintesi**; non nomina le altre cartelle del codice.

      La sezione sui dati dice che la cartella in Application Support contiene solo l'archivio e una cartella di registrazioni per chiamata, **senza `Models/`**.

      ## Chosen option

      ### Aggiornare il README

      Riscrivere *Layout* con tutte le cartelle di `Sources/LARP/` e il loro ruolo, aggiungere le sintesi all'elenco dei record e la cartella `Models/` alla descrizione dei dati. Cambia solo la documentazione.

      ## Where in the code

      README.md; Sources/LARP/App/LARPApp.swift; Sources/LARP/Archive/ArchiveView.swift; Sources/LARP/Model/ArchiveStore.swift; Sources/LARP/Model/AppPaths.swift
  88m7l084:
    title: 'Fix the code: Commento su Rifinisci testo'
    refs:
    - call/Awaiting refinement retry
    technical: false
    finished: 2026-11-11T13:23:19.462Z
    body: |-
      ## What happens

      Una chiamata **in attesa di ritentare la rifinitura** può essere rifinita di nuovo a richiesta con "Rifinisci testo" **anche quando la rifinitura è spenta** nelle impostazioni; il pulsante resta attivo in quel caso.

      ## What should happen

      Il commento che descrive quando "Rifinisci testo" si applica dice che serve **la rifinitura accesa** e una chiamata pronta o in attesa di essere rifinita di nuovo: per una chiamata in attesa di ritentare la rifinitura, il codice non guarda l'interruttore.

      ## Chosen option

      ### Correggere il commento

      Riscrivere il commento: la rifinitura deve essere accesa per una chiamata pronta, mentre una chiamata in attesa di ritentare la rifinitura si può rifinire anche a interruttore spento. Nessun cambio di comportamento.

      ## Where in the code

      Sources/LARP/Call/CallLifecycle+Refinement.swift; Sources/LARP/Call/CallStateMachine.swift
  bh3p4hew:
    title: 'Fix the code: Commento sul clic su una riga'
    refs:
    - playback
    technical: false
    finished: 2026-11-11T13:23:24.209Z
    body: |-
      ## What happens

      Un clic su una riga della trascrizione fa partire l'ascolto dall'inizio della riga **solo se la chiamata ha audio da riprodurre**: se nessuna traccia si legge, o la chiamata è ancora in registrazione, **non succede nulla**.

      ## What should happen

      Il commento della funzione che risponde al clic su una riga dice che porta in riproduzione **da qualunque stato**, senza eccezioni per le chiamate senza audio leggibile o ancora in registrazione.

      ## Chosen option

      ### Correggere il commento

      Aggiungere al commento che il clic non fa nulla quando la chiamata non ha audio da riprodurre. Nessun cambio di comportamento.

      ## Where in the code

      Sources/LARP/Playback/PlaybackController.swift
  e15ygp01:
    title: 'Fix the code: Commenti sull''avviso dell''eco'
    refs:
    - microphone
    - system-audio/Lost
    technical: false
    finished: 2026-11-11T13:23:32.966Z
    body: |-
      ## What happens

      La notizia se il suono degli altri viene tolto dal microfono arriva all'inizio della registrazione, a ogni riavvio del microfono e **anche quando l'audio di sistema torna** dopo essere stato perso, perfino se il microfono è ancora perso: in quel caso l'avviso di usare le cuffie può comparire.

      ## What should happen

      Due commenti dicono che la notizia arriva **solo** all'avvio e quando il **microfono** riparte (il commento sull'evento della cattura e quello del registratore); non dicono che arriva anche al ritorno dell'audio di sistema.

      ## Chosen option

      ### Correggere i due commenti

      Aggiungere in entrambi i commenti che la notizia arriva anche quando l'audio di sistema torna dopo essere stato perso. Nessun cambio di comportamento.

      ## Where in the code

      Sources/LARP/Recording/AudioCapturing.swift; Sources/LARP/Capture/Recorder.swift; Sources/LARP/Recording/SystemAudioTap.swift
  tgd5lphx:
    title: 'Fix the code: Commento sul limite di omp'
    refs:
    - requirements/rules#transcription
    technical: true
    finished: 2026-11-11T13:23:26.673Z
    body: |-
      ## What happens

      Le richieste di **rifinitura** e di **sintesi** concedono a omp fino a **600 secondi** in tutto, la prima risposta di apertura compresa. I **10 secondi** valgono solo per la verifica che omp sia raggiungibile.

      ## What should happen

      Il commento della costante di 10 secondi dice che è il tempo che omp ha per rispondere all'apertura della conversazione, **senza eccezioni**: chi lo legge si aspetta che anche rifinitura e sintesi falliscano dopo 10 secondi senza risposta.

      ## Chosen option

      ### Correggere il commento

      Scrivere che i 10 secondi sono il limite della verifica di omp e il valore predefinito, mentre rifinitura e sintesi passano il proprio limite di 600 secondi. Nessun cambio di comportamento.

      ## Where in the code

      Sources/LARP/Assistant/Omp.swift; Sources/LARP/Assistant/TranscriptRefiner.swift
---
# Commenti e README allineati al Model

Nessun cambio di comportamento. Il commento di Rifinisci testo distingue la chiamata pronta da quella in attesa di ritentare. I 10 secondi di omp valgono per la verifica, mentre rifinitura e sintesi usano 600 secondi. Il monitor di rete elenca tutti i lavori ritentati al ritorno della rete. Il clic su una riga non fa nulla senza audio da riprodurre. L'avviso dell'eco arriva anche al ritorno dell'audio di sistema. Il README descrive tutte le cartelle del codice, le sintesi e la cartella Models.
