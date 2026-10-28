---
created: 2026-10-28T16:24:06.775Z
updated: 2026-10-28T16:24:06.775Z
summary: Da Idle si registra a mano anche senza call app, con il solo microfono se l'audio di sistema manca; se il microfono si perde la registrazione prosegue in silenzio, e i titoli predefiniti sono "Registrazione del …".
tasks:
  - 3jgpvubb
  - ltg5uc7z
  - d6rosbr8
---
# Registrazione manuale senza call

L'avvio manuale richiede solo il permesso del microfono. Se l'audio di sistema non è disponibile si registra solo il microfono, con un pannello e `system.caf` vuoto. Il recorder ha i sub-States `Microphone on` e `Microphone lost`: quando il microfono non riparte dopo un cambio dei dispositivi la registrazione prosegue e `mic.caf` è riempito di silenzio, con un avviso. Le registrazioni senza call app si chiamano "Registrazione del …" in archivio, ricerca ed esportazione.
