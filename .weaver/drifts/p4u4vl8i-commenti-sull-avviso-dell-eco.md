---
status: fixed
refs:
- microphone
- system-audio/Lost
task: e15ygp01
option: 1
created: 2026-11-11T12:55:09.056Z
decided: 2026-11-11T13:22:37.635Z
---
# Commenti sull'avviso dell'eco

## What happens

La notizia se il suono degli altri viene tolto dal microfono arriva all'inizio della registrazione, a ogni riavvio del microfono e **anche quando l'audio di sistema torna** dopo essere stato perso, perfino se il microfono è ancora perso: in quel caso l'avviso di usare le cuffie può comparire.

## What should happen

Due commenti dicono che la notizia arriva **solo** all'avvio e quando il **microfono** riparte (il commento sull'evento della cattura e quello del registratore); non dicono che arriva anche al ritorno dell'audio di sistema.

## Fix options

### Correggere i due commenti

Aggiungere in entrambi i commenti che la notizia arriva anche quando l'audio di sistema torna dopo essere stato perso. Nessun cambio di comportamento.

### Commenti senza elenco

Dire solo che la notizia arriva ogni volta che l'eliminazione dell'eco riparte, senza elencare i casi. Nessun cambio di comportamento.

## Where in the code

Sources/LARP/Recording/AudioCapturing.swift; Sources/LARP/Capture/Recorder.swift; Sources/LARP/Recording/SystemAudioTap.swift

## Prepared question

```json
{
  "question": {
    "id": "p4u4vl8i",
    "question": "I commenti su `CaptureEvent.echoCancellation` e in `Recorder.captureEvent` dicono che la notizia sulla rimozione del suono degli altri dal microfono arriva solo all'avvio della registrazione e quando il microfono riparte. Come allineare commenti e comportamento?",
    "context": "Nel codice la notizia arriva all'avvio, a ogni ripartenza del microfono e anche quando l'audio di sistema torna dopo essere stato perso, perfino mentre il microfono è ancora perso (può comparire l'avviso delle cuffie). Posizioni: `Sources/LARP/Recording/AudioCapturing.swift`, `Sources/LARP/Capture/Recorder.swift`, `Sources/LARP/Recording/SystemAudioTap.swift` (ripartenza), `Sources/LARP/Recording/CallAudioCapture.swift` (filtro).",
    "options": [
      {
        "label": "Correggere i due commenti",
        "description": "I due commenti elencano tutti i momenti: avvio, ripartenza del microfono e ritorno dell'audio di sistema dopo una perdita, anche con il microfono ancora perso."
      },
      {
        "label": "Commenti senza elenco",
        "description": "I due commenti dicono solo che la notizia arriva ogni volta che la rimozione dell'eco riparte, senza elencare i momenti."
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
  "fingerprint": "sha256:7cba41381ed67dd212f4f101a36ec41fc6d1eaf49286fec89a16c1a3cc4d48ec",
  "prepared": "2026-11-11T12:56:13.775Z"
}
```
