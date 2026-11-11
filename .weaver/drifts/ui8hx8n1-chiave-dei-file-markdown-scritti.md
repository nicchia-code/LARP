---
status: proposal-accepted
refs:
- requirements/data#settings
proposal: guu6sj55
job: xiv2jzxe
created: 2026-11-11T17:48:11.980Z
decided: 2026-11-11T17:52:21.348Z
---
# Chiave dei file Markdown scritti

## What happens

Per non sovrascrivere i file dell'utente, LARP salva nelle impostazioni dell'app, per ogni cartella Markdown, l'elenco dei nomi dei file che ha scritto. Quest'elenco è un dato conservato in più rispetto a quelli descritti.

## What should happen

I Requirements dei dati delle impostazioni elencano uno per uno i valori che l'app conserva nelle impostazioni, e questo elenco di nomi non c'è. Il Task di correzione prevede di ricordare i file scritti da LARP, ma non dice dove conservarli.

## Fix options

### Conservare i nomi nell'archivio

I nomi dei file scritti si salvano insieme ai dati dell'archivio delle call e non nelle impostazioni, quindi nessuna chiave nuova. Costo: un campo in più nell'archivio e una migrazione dei dati.

### Riconoscere i file dal contenuto

LARP segna ogni file che scrive con un'indicazione dentro il file e riconosce così i propri. Niente elenco da salvare, ma il file esportato cambia e i file già scritti non si riconoscono più.

## Where in the code

Sources/LARP/Call/MarkdownFolderSync.swift (`MarkdownWrittenNames`); Sources/LARP/Settings/SettingsKey.swift

## Prepared question

```json
{
  "question": {
    "id": "ui8hx8n1",
    "question": "Dove deve conservare LARP i nomi dei file Markdown che ha scritto?",
    "context": "Per non sovrascrivere i file dell'utente nella cartella Markdown, LARP ricorda i nomi dei file che ha scritto, per ogni cartella. Oggi l'elenco sta nelle impostazioni dell'app con una chiave che i Requirements dei dati delle impostazioni non citano: questi Requirements elencano ogni valore conservato.",
    "options": [
      {
        "label": "Conservare i nomi nell'archivio",
        "description": "I nomi si salvano con i dati delle call, senza chiavi nuove nelle impostazioni.",
        "details": "Costo: un campo in più nell'archivio e una migrazione dei dati."
      },
      {
        "label": "Riconoscere i file dal contenuto",
        "description": "LARP segna i file che scrive e riconosce così i propri, senza elenco da salvare.",
        "details": "Il file esportato cambia e i file già scritti non si riconoscono più."
      },
      {
        "label": "Aggiungere la chiave ai Requirements",
        "description": "Il codice resta com'è e i Requirements elencano la nuova chiave delle impostazioni.",
        "details": "Nessuna modifica al codice."
      }
    ],
    "recommended": 2,
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
  "fingerprint": "sha256:6a5f228802f0d8170f00d44ad8f05ef4e1f40148776348a52887f7ba2518bc25",
  "prepared": "2026-11-11T17:48:17.101Z"
}
```
