---
created: 2026-10-27T16:33:43.344Z
updated: 2026-10-28T16:24:06.718Z
summary: "L'eco degli altri partecipanti è tolta dal microfono da WebRTC AEC3, senza voice processing di macOS: nessun volume cambia. Senza audio di sistema l'eco non si toglie e non compare alcun avviso."
tasks:
  - ha8n2ux7
  - svtdzv1x
---
# Eco rimossa con WebRTC AEC3

Il voice processing di macOS non è più attivo. Il microfono è ripulito durante la registrazione dall'echo canceller AEC3, con l'audio di sistema come riferimento, prima di `mic.caf` e della trascrizione dal vivo. Dopo un cambio dei dispositivi audio l'echo canceller riparte. Se non si può creare, la registrazione parte comunque e un pannello avvisa di usare le cuffie.
