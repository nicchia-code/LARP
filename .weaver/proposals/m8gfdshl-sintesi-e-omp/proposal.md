---
status: approved
kind: change
requires:
- 21la3pyo
base:
  model/actors/assistant.md: cc43bae2a20ac003c1f3c93556577309bc4ff5a11a62c9cdb92f608ee68707b9
  model/actors/user.md: 212bdb8a8b581d04a98e0c20938620647c8894b15c592d9851f0327404c96695
  model/library/call-question.md: new
  model/library/feature.md: db7d4aac7bc7121a4ddcfb7894903fbbbe59729ef8979db2fdc25b4374ed7f7f
  model/library/main-window.md: c2b67abb02f28de1743d50a33d887275b4bc24655b46d1cab722fcc1caef9e27
  model/library/playback.md: a36afafd5d360d07bb3043fcf8675e165cc7860539982641cb152168e06d2382
  model/library/transcript-translation.md: new
  model/settings/assistant-status.md: 93488f6a8b2d019229a202427a91821ec9c30c40f3d85e58312a4de751517dfd
  model/settings/call-questions.md: new
  model/settings/feature.md: c8deea470a9752657282b17be303cc3946e41b5fb26aecd0b9a1b611a7b91077
  model/settings/summary-language.md: new
  model/system.md: 52adacf06f2b150de88ddcd29bc68aa93ee664a954a55d708bda4d3795a3aff5
  model/transcription/call-summary.md: 3b8a750b5b6ded037410033e22162a5f720884ec5bb38aa35706f8b0f070dac9
  requirements/data/settings.md: fd47e7c3feaeedc0f30ff2deee1d7274630e7ee3d058c67d7845c92eb01fbbe7
  requirements/data/transcription.md: 3ceff424a43691b7210b0a735bd1c2dfbac990a0d13a911e9d1d20c77f8f5a75
  requirements/rules/library.md: 075ae0a483fa7b94fc3822034ab44ebafa5dd88198a99522677f48999f529a3a
  requirements/rules/settings.md: 3947e901d0a4cbd8733aefc8cdc261c064fb88f9820ab59d32f8f3b20dc32210
  requirements/rules/transcription.md: 7ff7f2ce21478479295014a3f9ea6b9213d17d68fb9e6ce88b0591536eb8e322
  requirements/ui/library.md: 9cb1247dfcbb7a03dc29c6123adffefda55a02cd5113398f88c88bc90223edb8
  requirements/ui/settings.md: f00b4aeceae8a2f11b5ad3637cbbb1e23d549ded688e6930a2ff546a10e05d24
created: 2026-11-11T14:53:42.747Z
label: 'Redesign: sintesi e omp'
job: oeg9sbc8
---
# Sintesi e omp

Quinta Proposal del redesign: porta la sintesi alla struttura della Style Guide e aggiunge le funzioni che usano omp (domande alla call e traduzione).

## Decisioni

- Sezioni della sintesi: frase d'apertura con la parte chiave evidenziata, Decisioni con l'ora che porta al punto della trascrizione, Azioni, Rimasto aperto, più le attuali Concetti chiave e Altro.
- Azioni complete: spuntabili, con responsabile e scadenza come detta nella call (testo, nessuna data calcolata, perché omp non riceve mai la data); rigenerare la sintesi azzera le spunte.
- Vista "Azioni" di tutte le call: raggruppate per call dalla più recente, aperte prima e fatte sotto barrate; un clic apre la call.
- Lingua della sintesi nelle Impostazioni: "Come la call", Italiano o English.
- "Chiedi qualcosa a questa call": la domanda va a omp con il testo della trascrizione come si vede (anche rifinito o corretto), con "Io" e "Partecipante N" e mai nomi, titolo, date o app; domande e risposte si accumulano finché la pagina resta aperta e non si salvano.
- "Traduci" con omp nell'altra lingua (italiano↔inglese), con lo stesso testo mostrato; un secondo clic torna all'originale; non si salva.
- Nuovo interruttore "Domande e traduzioni con omp", spento di default, nella sezione Sintesi, con lo stato di omp.
- L'esportazione Markdown (a mano e copia) include le nuove sezioni della sintesi con lo stato delle azioni, le note, i segnalibri e la trascrizione.
- Non sviluppati: modelli di sintesi (resta "Rigenera"), vocabolario personalizzato, rilevamento automatico della lingua, integrazioni Notion e Slack.

## Assunzioni dell'agente

- La card della call mostra la frase d'apertura della sintesi e, quando ci sono azioni aperte, la chip "<n> azioni".
- Una domanda o una traduzione in corso si annulla uscendo dalla pagina della call.
- Domande e traduzioni usano lo stesso limite di tempo di omp delle altre richieste (600 secondi).
