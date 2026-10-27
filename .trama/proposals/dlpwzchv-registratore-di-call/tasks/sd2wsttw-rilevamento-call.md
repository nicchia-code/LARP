---
refs:
  - capture
  - user
  - macos
  - macos.CALL_APP_MIC_STARTED
  - macos.CALL_APP_MIC_STOPPED
  - user.START_RECORDING
  - user.ACCEPT_PROPOSAL
  - user.STOP_RECORDING
  - requirements/tech#recorder
  - requirements/rules#recorder
  - requirements/ui#recorder
  - requirements/ui#recorder/Proposing
---
# Rilevamento call

Realizzare la macchina `recorder`: accorgersi che una call è iniziata, proporre di registrarla, avviare e fermare le registrazioni dalla barra dei menu. Esiste al massimo una registrazione alla volta.

Comportamento, come lo dice il Model:
- **Idle** (nessuna registrazione, nessuna proposta). Quando un'app di call nota inizia a usare il microfono → **Proposing**: compare la proposta di registrare con il nome dell'app. Con "Registra" dal menu: se i permessi di microfono e audio di sistema ci sono entrambi → **Recording**, registrazione non legata ad alcuna app, che si ferma solo a mano; se ne manca uno resta **Idle**, non si registra nulla e un avviso dice quale permesso manca e come concederlo nelle Impostazioni di Sistema.
- **Proposing**. Se l'utente accetta: con entrambi i permessi → **Recording**, la proposta sparisce e la registrazione è legata all'app che l'ha fatta scattare; se un permesso manca → **Idle**, la proposta sparisce, non si registra nulla e compare lo stesso avviso. Se l'app che ha fatto scattare la proposta smette di usare il microfono → **Idle**: la proposta sparisce e nulla è stato registrato (proposta ignorata, decisione dello sviluppatore). Mentre la proposta è visibile, "Registra" nel menu equivale ad accettarla.
- **Recording**. "Ferma registrazione" → **Idle**. Se la registrazione è legata a un'app di call e quell'app smette di usare il microfono → **Idle**: la registrazione finisce da sola, anche se un'altra app di call nota usa ancora il microfono.
- Un'app di call che inizia a usare il microfono mentre esiste già una proposta o una registrazione non ne crea una seconda.
- Emette `RECORDING_STARTED` all'avvio di una registrazione (nasce una nuova call) e `RECORDING_STOPPED` alla fine. Questo Task si ferma al controllo e agli eventi: la cattura e il salvataggio dell'audio sono del Task "Registrazione live".

Come costruirlo:
- Rilevamento con l'elenco dei processi Core Audio (`kAudioHardwarePropertyProcessObjectList`) e, per ciascuno, `kAudioProcessPropertyIsRunningInput` e il bundle identifier, ascoltando le notifiche di cambiamento invece di interrogare a intervalli; i processi helper (per esempio dei browser) sono ricondotti all'app madre.
- App di call note, definite in un unico punto del codice per poterle estendere: Zoom (`us.zoom.xos`), Microsoft Teams (`com.microsoft.teams2`, `com.microsoft.teams`), FaceTime (`com.apple.FaceTime`), Slack (`com.tinyspeck.slackmacgap`), Discord (`com.hnc.Discord`), Webex (`Cisco-Systems.Spark`, `com.webex.meetingmanager`), e i browser Safari (`com.apple.Safari`), Chrome (`com.google.Chrome`), Edge (`com.microsoft.edgemac`), Firefox (`org.mozilla.firefox`), Arc (`company.thebrowser.Browser`), Brave (`com.brave.Browser`).
- Permessi verificati prima di ogni avvio: microfono con l'autorizzazione di `AVAudioApplication`/`AVCaptureDevice`, audio di sistema dall'esito della creazione del process tap. L'avviso del permesso mancante è un alert che nomina il permesso e ha un pulsante che apre il pannello giusto delle Impostazioni di Sistema.
- La proposta è un piccolo pannello sotto l'icona della barra dei menu che non ruba il focus, con il testo "Call rilevata in <app>" e un pulsante "Registra"; resta finché viene accettata o finché l'app di call smette di usare il microfono.
- Icona della barra dei menu: contorno di microfono a riposo, pallino rosso pieno durante la registrazione con accanto il tempo trascorso. Il menu mostra "Registra" a riposo, "Ferma registrazione" durante la registrazione, poi "Apri archivio", "Impostazioni…" ed "Esci".
- Test con Swift Testing della logica di stato (sorgente di eventi Core Audio e permessi sostituibili nei test).
