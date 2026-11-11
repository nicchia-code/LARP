---
status: approved
kind: change
requires:
- m8gfdshl
base:
  model/actors/time.md: 7cdccd2146807da368b62f211112189c12e45d857565d73544de6e0392542895
  model/actors/user.md: 42ebb9a0156f87d01d58deeac06206f761befa392e4ca1e420709b592d8536c9
  model/library/main-window.md: 857bbed65288fd3233e02fbc6490187a817b9aa90a50c916b8507dac341ca8f7
  model/library/playback.md: e8491b2174bb65db2b6888cec0ea22c72f7ea4461e0687138c3a695391118398
  model/settings/audio-retention.md: new
  model/settings/feature.md: 51374b96d360d8383680195065428e3283e8839e5aa8c52e95300ccd8c9b89be
  model/settings/markdown-folder.md: new
  model/system.md: 1a0aa858625ceeaf62e2b0d2269a926b96d9ffbadf9f0cc8eb81c48d48bbae35
  model/transcription/call.md: 86d8ac6f1924a08ec5e6b33f9f36bd1a6ef2664280d821caa19cb8d88c5dc44c
  requirements/data/settings.md: 8fd13439a2c10c050bf8880ae3715849d094f04f9e6cb59f84b9037303a1d5d9
  requirements/data/transcription.md: 8be4a7f3c3467ec2afb31aad7b155041ed68271dbbf2bd9067cccd0cd2b29120
  requirements/rules/settings.md: dab889df704281aa46b5032f35dcd292a66cdff309b6589e7e0b832455d57f70
  requirements/tech/settings.md: 598e778b85b02d3cc894dad5c10e418d7c12d2db4e041f126ef012096876bc8a
  requirements/ui/settings.md: c9a71b7102148d1ca8c886c78865634d25df450e94a7758faebf896617d51bea
created: 2026-11-11T14:58:37.875Z
label: 'Redesign: file e archivio'
job: oeg9sbc8
---
# File e conservazione

Sesta e ultima Proposal del redesign: le funzioni della sezione "Privacy e archivio" e della cartella Markdown della Style Guide.

## Decisioni

- Cartella Markdown, spenta di default: l'utente sceglie una cartella e ogni call viene scritta come file .md quando la trascrizione è pronta e riscritta a ogni cambio di ciò che l'esportazione contiene; accendendola vengono scritte subito tutte le call pronte.
- Il file segue la call: prende il nuovo nome quando la call viene rinominata e si cancella quando la call viene eliminata.
- "Conserva i file audio": Sempre (default), 30 o 90 giorni; scaduto il tempo l'audio si cancella, trascrizione, sintesi, note e segnalibri restano e la call non si può più ascoltare.
- "Posizione dell'archivio": solo mostrata, con "Mostra nel Finder".
- Non sviluppati: "Elimina tutte le registrazioni", integrazioni con Notion, Slack o email.

## Assunzioni dell'agente

- Il controllo della scadenza dell'audio avviene all'avvio, ogni ora e subito dopo una nuova scelta; tocca solo le call pronte e senza una sintesi in scrittura.
- Cambiando cartella, i file già scritti nella cartella precedente restano dove sono e tutte le call pronte vengono scritte nella nuova; spegnendo la cartella i file restano.
- Due call con lo stesso titolo danno file distinti, il secondo con " (2)" e così via.
- Quando la cartella non si può scrivere, le Impostazioni lo dicono sotto la riga e la cartella resta accesa.
