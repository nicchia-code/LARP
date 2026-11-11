---
status: fixed
refs:
- call/Awaiting refinement retry
task: 88m7l084
option: 1
created: 2026-11-11T12:55:09.005Z
decided: 2026-11-11T13:22:24.785Z
---
# Commento su Rifinisci testo

## What happens

Una chiamata **in attesa di ritentare la rifinitura** può essere rifinita di nuovo a richiesta con "Rifinisci testo" **anche quando la rifinitura è spenta** nelle impostazioni; il pulsante resta attivo in quel caso.

## What should happen

Il commento che descrive quando "Rifinisci testo" si applica dice che serve **la rifinitura accesa** e una chiamata pronta o in attesa di essere rifinita di nuovo: per una chiamata in attesa di ritentare la rifinitura, il codice non guarda l'interruttore.

## Fix options

### Correggere il commento

Riscrivere il commento: la rifinitura deve essere accesa per una chiamata pronta, mentre una chiamata in attesa di ritentare la rifinitura si può rifinire anche a interruttore spento. Nessun cambio di comportamento.

### Togliere il commento

Eliminare la frase sulle condizioni, lasciando che sia la tabella delle transizioni a dirle. Nessun cambio di comportamento.

## Where in the code

Sources/LARP/Call/CallLifecycle+Refinement.swift; Sources/LARP/Call/CallStateMachine.swift

## Prepared question

```json
{
  "question": {
    "id": "tuoqy23i",
    "question": "Come trattare il commento su \"Rifinisci testo\"?",
    "context": "Il commento di canRefine dice che \"Rifinisci testo\" vale solo con la rifinitura attiva e la chiamata pronta o in attesa di essere rifinita di nuovo, ma una chiamata in attesa di un nuovo tentativo di rifinitura può essere rifinita su richiesta anche con la rifinitura disattivata, e il pulsante resta attivo.",
    "options": [
      {
        "label": "Correggere il commento",
        "description": "Il commento di canRefine viene riscritto per descrivere quando il pulsante è davvero disponibile, compreso il caso della chiamata in attesa di un nuovo tentativo con la rifinitura disattivata."
      },
      {
        "label": "Togliere il commento",
        "description": "Dal commento di canRefine viene tolta la frase sulle condizioni; resta solo l'indicazione che dice se \"Rifinisci testo\" si applica."
      },
      {
        "label": "Lasciare tutto com'è",
        "description": "Codice e commento restano invariati."
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
  "fingerprint": "sha256:bd5ec6ff0d107f0ecb1dc550b009bf5dbee0f9dbf61c6cfcb59176129668cebb",
  "prepared": "2026-11-11T12:56:13.369Z"
}
```
