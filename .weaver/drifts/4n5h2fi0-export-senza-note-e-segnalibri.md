---
status: fixed
refs:
- requirements/rules#main-window
proposal: sfewvyf4
task: vglhu2ph
option: 1
job: xiv2jzxe
created: 2026-11-11T17:32:54.379Z
decided: 2026-11-11T17:52:29.043Z
---
# Export senza note e segnalibri

## What happens

L'esportazione Markdown scrive il titolo, la riga con data e durata e la trascrizione. Le **note** e i **segnalibri** della call non compaiono mai nel file. Il titolo `## Trascrizione` compare solo quando la call ha una sintesi: senza sintesi le righe della trascrizione seguono la riga con data e durata senza titolo.

## What should happen

I Requirements definiscono l'esportazione in sei parti: la parte 4 `## Note` con una riga `- [<orologio>] <testo>` per nota (o `- <testo>` senza ora), solo se la call ha note; la parte 5 `## Segnalibri` con una riga per segnalibro, solo se ce ne sono; la parte 6 `## Trascrizione` sempre, seguita dai paragrafi delle righe.

## Fix options

### Estendere l'esportazione esistente

L'esportazione scrive le parti 4 e 5 quando ci sono note o segnalibri e il titolo `## Trascrizione` sempre. Cambia il contenuto dei file esportati e della cartella Markdown; costo: aggiornare i test che oggi non si aspettano il titolo senza sintesi.

### Costruire le parti in un punto solo

Le parti di note e segnalibri vengono costruite in un generatore condiviso da esportazione, copia della sintesi e cartella Markdown, con il titolo della trascrizione sempre scritto. Stesso risultato per l'utente; costo: un piccolo riordino del codice di esportazione oltre ai test.

## Where in the code

Sources/LARP/Archive/TranscriptExport.swift (`markdown(for:)`); Tests/LARPTests/TranscriptExportTests.swift

## Prepared question

```json
{
  "question": {
    "id": "4n5h2fi0",
    "question": "Come deve comportarsi l'esportazione Markdown con note, segnalibri e titolo della trascrizione?",
    "context": "I Requirements dicono che il file esportato ha, dopo la sintesi, una parte `## Note` (solo se la call ha note), una parte `## Segnalibri` (solo se ci sono segnalibri) e il titolo `## Trascrizione` sempre. Oggi il file contiene titolo, riga con data e durata, sintesi (se c'è) e trascrizione: note e segnalibri non compaiono mai e il titolo `## Trascrizione` c'è solo con una sintesi. La differenza tocca l'esportazione, la cartella Markdown e la copia della trascrizione.",
    "options": [
      {
        "label": "Estendere l'esportazione esistente",
        "description": "Il file scrive note e segnalibri quando ci sono e sempre il titolo della trascrizione, come dicono i Requirements.",
        "details": "Cambia il contenuto dei file esportati e della cartella Markdown. Costo: aggiornare i test che oggi non si aspettano il titolo senza sintesi."
      },
      {
        "label": "Costruire le parti in un punto solo",
        "description": "Stesso risultato per l'utente, con le parti di note e segnalibri costruite in un generatore condiviso da esportazione, copia della sintesi e cartella Markdown.",
        "details": "Costo: un piccolo riordino del codice di esportazione oltre ai test."
      },
      {
        "label": "Mantenere l'esportazione com'è",
        "description": "Note e segnalibri restano fuori dal file e il titolo della trascrizione compare solo con una sintesi; i Requirements si adeguano.",
        "details": "Nessuna modifica al codice. Le note e i segnalibri scritti dall'utente non arrivano nei file Markdown."
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
  "fingerprint": "sha256:54b2b27d16cf372590e1a1110049753a8a50e8124e5aded3ff714ba5766ad1bd",
  "prepared": "2026-11-11T17:47:23.395Z"
}
```
