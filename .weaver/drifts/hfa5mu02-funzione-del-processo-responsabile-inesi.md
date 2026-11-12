---
status: fixed
refs:
- requirements/tech#recorder
- requirements/rules#recorder
origin: ud0aojaq
proposal: k17e6q19
task: xvslygrj
option: 1
job: cnb7b62w
created: 2026-11-12T15:36:54.621Z
decided: 2026-11-12T15:53:53.107Z
---
# Funzione del processo responsabile inesistente su macOS

## What happens

Il rilevamento cerca a run time `responsibility_get_pid_for_pid`, il nome scritto nei Requisiti. Su questo Mac (macOS 27, verificato con `dlsym` da un processo di prova) quel simbolo **non esiste**: la ricerca fallisce sempre, il processo responsabile non viene mai letto e valgono solo le regole successive. Il simbolo che esiste e restituisce il responsabile è `responsibility_get_pid_responsible_for_pid`. Di conseguenza gli helper avviati dal sistema e gli helper con l'identificatore di un'altra app (Edge dentro Teams) non sono attribuiti correttamente.

## What should happen

I Requisiti chiedono che un processo al microfono sia attribuito prima di tutto all'app responsabile, letta con una funzione di macOS cercata con `dlsym`. Con il nome scritto la funzione non può essere trovata, quindi il requisito non si può rispettare sulla piattaforma così com'è; il Task chiede inoltre che il Task sia verificabile con un responsabile reale.

## Fix options

### Provare il nome scritto e poi quello reale

La ricerca prova prima `responsibility_get_pid_for_pid` come da Requisiti e, se manca, `responsibility_get_pid_responsible_for_pid`. Il comportamento atteso (responsabile letto, ricaduta sulle regole successive se manca) si ottiene senza cambiare i Requisiti; costo: una riga in più e un nome nel codice che oggi non esiste.

### Cercare solo il nome reale

La ricerca usa soltanto `responsibility_get_pid_responsible_for_pid`. Codice più semplice, ma il nome non coincide con quello dei Requisiti, che andrebbero corretti in seguito.

## Where in the code

Sources/LARP/Capture/ProcessInfoReading.swift, `SystemProcessInfoReader` (ricerca con `dlsym`)

## Prepared question

```json
{
  "question": {
    "id": "hfa5mu02",
    "question": "Come si ottiene il processo responsabile, se la funzione dei Requisiti non esiste su macOS?",
    "context": "Il rilevamento delle call deve attribuire un processo che usa il microfono all'app di call che macOS considera responsabile, leggendola con una funzione di macOS cercata a run time. I Requisiti chiamano la funzione `responsibility_get_pid_for_pid`, ma su macOS 27 non esiste: esiste solo `responsibility_get_pid_responsible_for_pid`. Oggi la ricerca fallisce sempre e il responsabile non viene mai letto: gli helper avviati dal sistema e gli helper con l'identificatore di un'altra app (per esempio Edge dentro Teams) non sono attribuiti correttamente.",
    "options": [
      {
        "label": "Provare il nome scritto, poi quello reale",
        "description": "Il codice cerca prima il nome dei Requisiti e, se manca, quello reale; i Requisiti restano com'erano."
      },
      {
        "label": "Cercare solo il nome reale",
        "description": "Il codice usa solo `responsibility_get_pid_responsible_for_pid`; il nome dei Requisiti non coincide con il codice."
      },
      {
        "label": "Correggere i Requisiti con il nome reale",
        "description": "Il Requisito indica `responsibility_get_pid_responsible_for_pid` e il codice si allinea a quel nome.",
        "details": "Usa la bozza di Proposal allegata, che cambia solo il nome della funzione nel Requisito di rilevamento delle app di call."
      }
    ],
    "recommended": 0,
    "multi": false
  },
  "decisions": [
    {
      "decision": "fix-code",
      "option": 1
    },
    {
      "decision": "fix-code",
      "option": 2
    },
    {
      "decision": "proposal"
    }
  ],
  "fingerprint": "sha256:d2979ca19e27eafc5104d1076427b52267d491370ebe0a0210f0cbda5f66854e",
  "prepared": "2026-11-12T15:52:31.878Z"
}
```
