---
technical: false
refs:
  - call-summaries
  - user.TURN_ON_SUMMARY
  - user.TURN_OFF_SUMMARY
  - requirements/ui#settings
  - requirements/rules#settings
  - requirements/data#General
---
# Interruttore Sintesi con omp

Nelle impostazioni compare l'interruttore «Sintesi con omp», indipendente da «Rifinisci il testo con omp» e spento per impostazione predefinita. L'utente lo accende con `user.TURN_ON_SUMMARY` e lo spegne con `user.TURN_OFF_SUMMARY`.

La Machine `call-summaries` ha due State:
- Off (iniziale): nessuna chiamata viene sintetizzata, né da sola né su richiesta. Le sintesi già scritte restano leggibili, cercabili ed esportabili. `user.TURN_ON_SUMMARY` porta a On.
- On: le nuove chiamate vengono sintetizzate da sole dopo la separazione dei partecipanti, e l'utente può chiedere di sintetizzare qualsiasi chiamata i cui partecipanti sono stati distinti. `user.TURN_OFF_SUMMARY` porta a Off: le sintesi in scrittura o in attesa di nuovo tentativo si fermano; quelle già scritte restano.
Nulla di una trascrizione lascia il Mac per una sintesi mentre la sintesi è spenta.

Il controller dell'interruttore (sul modello di `TranscriptRefinementController`, Settings/) espone lo stato acceso/spento e un segnale di spegnimento (come `turnOffEvents`), che la sintesi per chiamata (`call-summary`, altro Task) usa per fermare le sintesi in corso, e che `assistant-status` usa per decidere se omp serve ancora. Questo Task non avvia né ferma le sintesi delle singole chiamate.

Impostazioni salvate: transcription language, transcript refinement, call summaries e launch at login stanno in `UserDefaults` (nuova chiave accanto a `SettingsKey.transcriptRefinement` in Settings/SettingsKey.swift); tutto il resto resta in `~/Library/Application Support/LARP/` (store SwiftData e cartella `Recordings/<call id>/` per chiamata). Valori predefiniti al primo avvio: lingua italiana, rifinitura spenta, sintesi spenta, avvio all'accesso spento.

Finestra delle impostazioni (Settings/SettingsView.swift, `SettingsView.body`): lingua di trascrizione («Italiano», «English») con il suo stato («Pronta», «Download in corso…», «Non disponibile, nuovo tentativo appena possibile»), l'interruttore «Rifinisci il testo con omp», l'interruttore «Sintesi con omp» e l'interruttore «Avvia all'accesso». Mentre «Rifinisci il testo con omp» o «Sintesi con omp» è acceso, lo stato di omp viene mostrato una sola volta, sotto i due interruttori: «Verifica in corso…», «omp pronto» o «omp non trovato» (oggi `assistantText` lo mostra sotto il solo interruttore di rifinitura; deve leggere lo stato di `assistant-status`).
