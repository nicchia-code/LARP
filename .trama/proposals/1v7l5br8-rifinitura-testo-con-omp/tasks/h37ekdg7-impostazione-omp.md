---
refs:
  - transcript-refinement
  - settings
  - assistant
  - user.OPEN_SETTINGS
  - user.TURN_ON_REFINEMENT
  - user.TURN_OFF_REFINEMENT
  - requirements/tech#transcript-refinement
  - requirements/ui#settings
  - requirements/rules#settings
  - requirements/data#General
  - specs#frameworks
---
# Interruttore e verifica di omp

Quando il lavoro è finito, le impostazioni hanno l'interruttore "Rifinisci il testo con omp", accanto alla lingua di trascrizione e prima di "Avvia all'accesso". L'interruttore è spento di default e il suo valore è salvato in `UserDefaults` come le altre impostazioni.

La macchina `transcript-refinement` è implementata così:
- **Off** (iniziale): nessuna call viene rifinita, né da sola né su richiesta. `user.TURN_ON_REFINEMENT` porta a **On**.
- **On**: entra in **Checking**. `user.TURN_OFF_REFINEMENT` riporta a **Off**. `macos.APP_LAUNCHED` e `user.OPEN_SETTINGS` (apertura della finestra delle impostazioni) riportano a **Checking** per cercare di nuovo omp.
  - **Checking**: si cerca omp e gli si chiede di rispondere. `assistant.REACHED` porta a **Assistant ready**, `assistant.UNREACHABLE` a **Assistant missing**.
  - **Assistant ready**: omp trovato e risponde.
  - **Assistant missing**: omp non trovato o non risponde. Le call vengono comunque mandate in rifinitura, che fallisce e si riprova più tardi.

Con l'interruttore acceso, accanto a esso si vede lo stato di omp: "Verifica in corso…" in Checking, "omp pronto" in Assistant ready, "omp non trovato" in Assistant missing. Con l'interruttore spento non si mostra nessuno stato.

La verifica, che produce `assistant.REACHED` o `assistant.UNREACHABLE`:
- cerca omp attraverso la shell di login dell'utente (`$SHELL -l -c 'command -v omp'`), perché le app aperte dal Finder non ricevono il `PATH` della shell; la ricerca si ripete a ogni verifica e a ogni rifinitura;
- avvia omp con `Foundation.Process` come `omp acp`, con gli strumenti integrati disattivati e senza sessione salvata quando omp accetta le opzioni (`--no-tools`, `--no-session`), in una nuova cartella temporanea vuota come cartella di lavoro, cancellata alla fine;
- parla il protocollo ACP (JSON-RPC 2.0, un messaggio per riga su input e output standard) direttamente, senza nuove dipendenze di pacchetti: FluidAudio resta l'unica dipendenza di terze parti;
- in `initialize` dichiara di non offrire file system né terminale;
- considera omp raggiunto se `initialize` riceve risposta entro 10 secondi; omp non trovato, un errore o nessuna risposta in tempo significano non raggiungibile; poi chiude il processo.

Il client ACP scritto qui serve anche alla rifinitura delle call. Per questo deve anche permettere di aprire una sessione (`session/new`), mandare un prompt (`session/prompt`), raccogliere il testo dei messaggi `session/update` fino alla fine del prompt e rifiutare ogni `session/request_permission`. Usa le credenziali già configurate in omp e non sceglie mai un modello: omp usa il suo modello predefinito. Il processo si deve poter terminare in qualsiasi momento.
