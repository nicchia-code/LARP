---
status: approved
base:
  capture/recorder.md: d55b0ad004fcfc2635b680811376a7469f633a544e29552379c44a4a7fc7acce
  requirements/tech/area.md: 06aa9f00c99a631ad469c427f5e1d13d178fcbe4f810eb5d8642a864a7f70ba1
  specs.yaml: 38eec2cdf3e99804bbc77ba87d3a731a6b220b958e713e3de54724646e28ae2d
  requirements/tech/stack.md: a1fe9347b8496d1e98e4a9e8316fb2fed978850b6882190880b8b45ec0878a11
  requirements/quality/main.md: 299d210fe6844b92c87c96b1aea17bb7ef35e90d895871506c8919d5023193c8
delete: []
request: 2026-10-28T15-32-36
created: 2026-10-28T15:10:29.628Z
label: Eco senza ducking
---
# Eco senza abbassare i volumi

Durante la registrazione il volume della chiamata si abbassa in modo significativo: per togliere dal microfono la voce degli altri partecipanti, LARP attiva il voice processing di macOS, che abbassa (ducking) l'audio di tutte le altre app, compresa l'app della chiamata, e con l'AGC può cambiare il livello del microfono; con buona probabilità abbassa anche la traccia dell'audio di sistema registrata. Lo sviluppatore considera un problema tutto questo: audio della chiamata in diretta, audio delle registrazioni e voce dell'utente per gli altri.

Decisioni:
- LARP non usa più il voice processing di macOS: toglie da sé l'eco dal microfono, usando come riferimento l'audio di sistema che già registra; la registrazione non cambia nessun volume del Mac né il livello del microfono usato dall'app della chiamata.
- Componente: WebRTC AEC3, incluso nel progetto come pacchetto Swift Package Manager.
- L'eco è tolta durante la registrazione, prima che il microfono sia salvato e trascritto dal vivo.
- Se la rimozione dell'eco non riesce a partire o a ripartire, la registrazione parte o continua senza rimuoverla e l'utente è avvisato di usare le cuffie, come oggi.
- La rimozione dell'eco è sempre attiva, qualunque sia l'uscita audio; nessun rilevamento di cuffie o altoparlanti.
- Nessuna regolazione di livello delle registrazioni, né in registrazione né in riascolto: basta togliere la causa; le chiamate già registrate restano come sono.
- Verifica: test automatico con audio sintetico (eco simulata nel microfono) e prova manuale su un Mac reale per volumi ed eco.

Scelte dell'agente, da verificare:
- Soglie del test automatico: dopo i primi 2 secondi, eco ridotta di almeno 20 dB e voce dell'utente mantenuta entro 3 dB.
- AEC3 riceve entrambi i segnali in 16 kHz mono a frame di 10 ms, con il ritardo lasciato alla sua stima interna; gira su una coda seriale propria, mai sul thread di I/O di Core Audio.
- Il modulo audio processing di WebRTC è compilato dal sorgente come target C++ di Swift Package Manager fissato a una revisione, con solo l'echo canceller attivo (niente gain control né noise suppression).
- A ogni cambio di dispositivi audio l'echo canceller viene azzerato perché si adatti al nuovo percorso.

Rifinitura sul Model attuale (scelte dell'agente, da verificare):
- Il Model ora permette di registrare a mano solo il microfono quando l'audio di sistema non è disponibile: senza audio di sistema manca il riferimento, quindi in quel caso l'eco non è tolta, il microfono tiene tutto quello che raccoglie e l'avviso di usare le cuffie non compare (come già dice `requirements/ui#recorder/Recording`). Prima, con il voice processing di macOS, l'eco era tolta anche senza audio di sistema.
- Il cambio di dispositivi audio ora vive negli stati `Microphone on` e `Microphone lost`, mantenuti come sono: la rimozione dell'eco riparte, con l'echo canceller azzerato, quando il microfono riparte in `Microphone on` e quando torna da `Microphone lost`; l'avviso cuffie si ripete solo se l'audio di sistema è registrato.
- Mantenuti i requisiti arrivati nel frattempo: verifica su Mac reale di «Registra» senza chiamata, richiesta del permesso del microfono con il prompt di macOS, registrazione manuale con solo il microfono e passaggio a `Microphone lost` quando il motore non riparte (che ora riparte sempre senza voice processing).
