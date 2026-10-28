---
status: approved
base:
  capture/recorder.md: 1190beda66c12222a497e7249a6c2af7564247bc1a22809d6e8d6310a1179e43
  actors/macos.md: 783ed080e48c62dcf5e508542118ee450335979ac48ae12e9379aaba790e075f
  requirements/tech/stack.md: 6c964b65af1dfa1a81c376251c2cf4039b0a7b00bcc8a1868643ef1f4a9fa1f6
  requirements/ui/screens.md: 4a1622beaec16fae43827a3e2918d017199a5bda450fe26d45630d6b2774eb46
  requirements/quality/main.md: cf33fec35cd4efb2033fe7fc59a3bc23d0d634b84b240ff85769c7369b8c4b15
delete: []
request: 2026-10-27T16-46-19
created: 2026-10-27T16:27:41.784Z
label: Cancellazione eco
---
# Eco degli altri senza cuffie

Senza cuffie gli altoparlanti del Mac riproducono gli altri partecipanti e il microfono li riprende: oggi la traccia del microfono viene registrata senza alcuna cancellazione dell'eco, quindi gli altri finiscono sia nella traccia del microfono sia in quella dell'audio di sistema. In riascolto le due tracce sommate fanno sentire gli altri due volte e nella trascrizione le loro frasi possono comparire come righe "Io".

Decisioni:
- Vanno corretti sia il riascolto sia la trascrizione.
- Il suono degli altri viene tolto dal microfono durante la registrazione, con la cancellazione dell'eco (voice processing) di macOS sul microfono.
- La cancellazione è sempre attiva, con cuffie o altoparlanti: nessun rilevamento dell'uscita audio.
- Il volume delle altre app, compresa quella della chiamata, viene abbassato da macOS il meno possibile.
- Il controllo automatico del volume della voce dell'utente resta come lo imposta macOS.
- Se la cancellazione non si riesce ad attivare la registrazione parte comunque e l'utente viene avvisato: "Cancellazione dell'eco non disponibile: usa le cuffie per non sentire gli altri due volte."
- L'avviso è un pannello sotto l'icona nella barra dei menu che non prende il fuoco e sparisce da solo dopo 10 secondi.
- Se la cancellazione smette di funzionare durante la registrazione (cambio di microfono o uscita audio) la registrazione continua e compare lo stesso avviso.
- Le chiamate già registrate restano come sono.
- L'allineamento dell'inizio delle due tracce resta fuori da questa modifica.

Assunzioni:
- Il cambio dei dispositivi audio del Mac è un nuovo evento di macOS, ricevuto dal registratore durante la registrazione.
- Che la cancellazione di macOS tolga anche l'audio riprodotto dalle app di chiamata va verificato su un Mac reale con gli altoparlanti.
