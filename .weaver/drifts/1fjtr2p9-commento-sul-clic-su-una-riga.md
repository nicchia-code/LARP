---
status: fixed
refs:
- playback
task: bh3p4hew
option: 1
created: 2026-11-11T12:55:09.039Z
decided: 2026-11-11T13:22:29.618Z
---
# Commento sul clic su una riga

## What happens

Un clic su una riga della trascrizione fa partire l'ascolto dall'inizio della riga **solo se la chiamata ha audio da riprodurre**: se nessuna traccia si legge, o la chiamata è ancora in registrazione, **non succede nulla**.

## What should happen

Il commento della funzione che risponde al clic su una riga dice che porta in riproduzione **da qualunque stato**, senza eccezioni per le chiamate senza audio leggibile o ancora in registrazione.

## Fix options

### Correggere il commento

Aggiungere al commento che il clic non fa nulla quando la chiamata non ha audio da riprodurre. Nessun cambio di comportamento.

### Togliere "da qualunque stato"

Accorciare il commento a "riproduce dall'inizio della riga", lasciando le condizioni al codice. Nessun cambio di comportamento.

## Where in the code

Sources/LARP/Playback/PlaybackController.swift

## Prepared question

```json
{
  "question": {
    "id": "1fjtr2p9",
    "question": "Il commento di `play(fromSentenceStart:)` dice che il clic su una riga della trascrizione avvia la riproduzione «da qualunque stato». Come allineare commento e comportamento?",
    "context": "Nel codice il clic su una riga avvia la riproduzione dall'inizio della frase solo se la chiamata ha un audio riproducibile; se la traccia non è leggibile o se è in corso una registrazione, non succede nulla. Posizione: `Sources/LARP/Playback/PlaybackController.swift`.",
    "options": [
      {
        "label": "Correggere il commento",
        "description": "Il commento aggiunge il caso senza audio: senza traccia leggibile o durante una registrazione il clic non ha effetto."
      },
      {
        "label": "Togliere \"da qualunque stato\"",
        "description": "Il commento si accorcia e dice solo che il clic avvia la riproduzione dall'inizio della frase."
      },
      {
        "label": "Lasciare tutto com'è",
        "description": "Codice, commenti e README restano invariati."
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
  "fingerprint": "sha256:4f014f56ee2ab2dc3ef2f8f59133ba78c868652b09757f2d4f8504c092a5aec5",
  "prepared": "2026-11-11T12:56:13.735Z"
}
```
