---
status: fixed
refs:
- requirements/tech#General
- requirements/data#General
task: bbsx5rpf
option: 1
created: 2026-11-11T12:55:08.985Z
decided: 2026-11-11T13:22:18.535Z
---
# README: cartelle e archivio

## What happens

Il codice è diviso in molte cartelle per area: la **finestra archivio** ha una cartella sua (archivio, riproduzione, chiamata, cattura, registrazione, trascrizione, separazione, assistente, rifinitura, sintesi, impostazioni, modello, app).

L'archivio tiene **quattro** tipi di record: chiamate, righe di trascrizione, partecipanti e **sintesi**. Nella cartella dell'app in Application Support c'è anche la cartella **`Models/`** con i modelli per separare le voci, scaricati al primo uso.

## What should happen

La sezione *Layout* del README dice che la cartella dell'app contiene anche la **finestra archivio** e che il modello conserva solo chiamate, righe e partecipanti, senza le **sintesi**; non nomina le altre cartelle del codice.

La sezione sui dati dice che la cartella in Application Support contiene solo l'archivio e una cartella di registrazioni per chiamata, **senza `Models/`**.

## Fix options

### Aggiornare il README

Riscrivere *Layout* con tutte le cartelle di `Sources/LARP/` e il loro ruolo, aggiungere le sintesi all'elenco dei record e la cartella `Models/` alla descrizione dei dati. Cambia solo la documentazione.

### Accorciare il Layout

Lasciare nel README solo le cartelle di primo livello del repository, togliere l'elenco dei record e descrivere i dati in Application Support senza elencarne ogni file, così il testo non invecchia a ogni nuova cartella.

## Where in the code

README.md; Sources/LARP/App/LARPApp.swift; Sources/LARP/Archive/ArchiveView.swift; Sources/LARP/Model/ArchiveStore.swift; Sources/LARP/Model/AppPaths.swift

## Prepared question

```json
{
  "question": {
    "id": "wezfz2on",
    "question": "Il README descrive le cartelle del codice e i dati salvati in modo diverso da come sono. Come procedere?",
    "options": [
      {
        "label": "Aggiornare il README",
        "description": "Riscrivere la sezione Layout con tutte le cartelle (anche Archive/), aggiungere i riassunti tra i dati dell'archivio e la cartella Models/ con i modelli di separazione delle voci."
      },
      {
        "label": "Accorciare il Layout",
        "description": "Lasciare nel README solo le cartelle principali, togliere l'elenco dei tipi di dati e descrivere i dati salvati senza elencare ogni file."
      },
      {
        "label": "Lasciare tutto com'è",
        "description": "Non modificare né il README né il codice."
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
      "decision": "dismissed"
    }
  ],
  "fingerprint": "sha256:c9c23c385db04f15857fc89986598f1e0633aebe88d1d358fa48e254f929d3f0",
  "prepared": "2026-11-11T12:55:55.508Z"
}
```
