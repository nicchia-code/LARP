---
refs:
  - recording-view
  - requirements/tech#recording-view
  - requirements/ui#recording-view
  - user.OPEN_LIVE_WINDOW
  - user.CLOSE_LIVE_WINDOW
---
# Pillola e finestra dal vivo

Durante una registrazione si mostra esattamente uno tra la pillola e la finestra dal vivo; fuori da una registrazione nessuno dei due.

## Cosa deve valere

- All'avvio della registrazione compare la pillola; alla fine sparisce la pillola o la finestra dal vivo. Entrambe mostrano il tempo trascorso con un punto rosso ("In pausa" / "IN PAUSA" in pausa), una forma d'onda di quanto catturano microfono e audio di sistema (piatta in pausa) e offrono "Segnalibro", "Pausa"/"Riprendi" e "Ferma".
- **Pillola**: barra ink 64 px, raggio 32, circa 390 px, 24 px sopra il bordo inferiore, centrata sullo schermo della barra dei menu, su ogni Space e accanto alle app a tutto schermo, sopra ogni finestra senza prendere il focus; punto `#FF5A40` (`#A3A69B` in pausa), tempo in JetBrains Mono 16 px, circa 20 barre lime, tre bottoni tondi da 44 px con nome come tooltip ed etichetta di accessibilità. Un clic sul tempo o sulla forma d'onda apre la finestra dal vivo (anche "Apri finestra dal vivo" nella finestra a comparsa): la pillola sparisce mentre la finestra è aperta; chiudendo la finestra la pillola torna.
- **Finestra dal vivo**, aperta solo a richiesta: circa 1040 × 680 px, ink, aspetto scuro, senza barra del titolo, finestra normale che viene in primo piano senza far apparire l'app nel Dock.
  - In alto: chip "REC <tempo>" (o "IN PAUSA"), titolo della call, "· <app o "Manuale"> · <lingua>" oppure che non c'è trascrizione dal vivo, livelli "Call" e "Mic".
  - Al centro: le righe finali con il punto di "Io" o "Altri", ora e testo, "· SEGNALIBRO" sulla riga all'ora di un segnalibro; in basso, grande, il testo in riconoscimento con "<SPEAKER> · STA PARLANDO", le ultime parole in `#8A8D82`. Questo testo viene dai risultati volatili della trascrizione dal vivo, sostituito a ogni risultato, e non è mai salvato; solo i risultati finali diventano righe. Scorre da sola all'ultima riga salvo se l'utente è risalito; riprende a seguire tornando in fondo.
  - A destra "Nella call" con "Io" e "Altri" e il segno su chi parla ora, e "Le tue note" con le note della call in ordine di tempo e il campo "Scrivi una nota…" che aggiunge con Invio, al tempo trascorso.
  - In basso: forma d'onda larga (ultimo minuto lime, il resto `#3A3C36`), "Segnalibro" con la sua scorciatoia, "Pausa"/"Riprendi", "Ferma" lime.
- **Livelli**: picco degli ultimi 50 ms per traccia, 20 volte al secondo, scala da −60 a 0 dBFS; una traccia parla se resta sopra −40 dBFS per almeno 200 ms e smette 500 ms dopo essere scesa sotto; in pausa tutti vuoti. Misurati sulla coda privata di ogni traccia dall'audio a 16 kHz prima della scrittura, mai sui thread audio, consegnati al main actor al massimo 20 volte al secondo.

## Code notes
Commit: 58d947126f08b8c7e4128d08782a627080bde977
- Pannelli: `Sources/LARP/Capture/RecorderPresenters.swift` `MenuBarPanel` (creazione NSPanel, `origin(for:below:)`); trova la status item con `className.contains("StatusBar")`, fragile ma riutilizzabile per lo schermo della pillola. La pillola è un pannello non attivante a livello floating.
- Ogni effetto UI passa da un presenter `@MainActor` dietro protocollo con fake nei test; nessuna infrastruttura di test UI: testare solo logica (livelli, chi parla).
- `LSUIElement`: serve `NSApp.activate()` prima di `openWindow`. Scene in `Sources/LARP/App/LARPApp.swift`.
- Livelli: `Sources/LARP/Recording/TrackPipeline.swift` `process`; non toccare il main actor dal thread audio.
- Testo volatile: `Sources/LARP/Transcription/SpeechTranscriptionService.swift` `SpeechTrackConfiguration.line` oggi scarta i risultati volatili; righe dal vivo in `Sources/LARP/Call/CallLifecycle+Recording.swift` `appendLiveLine`, `LiveAudioRelay` (`appendLiveLine` non salva).
- Le righe dal vivo possono essere scartate alla fine: segnalibri e note non vanno legati alle righe.
