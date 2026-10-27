---
refs:
  - settings
  - user.CHOOSE_LANGUAGE
  - macos.LANGUAGE_INSTALLED
  - macos.LANGUAGE_DOWNLOAD_FAILED
  - requirements/tech#transcription-language
  - requirements/tech#settings
  - requirements/rules#settings
  - requirements/ui#settings
---
# Lingua e impostazioni

Realizzare la finestra delle impostazioni e la macchina `transcription-language`: l'unica lingua, italiano o inglese, in cui si trascrivono tutte le call (decisione dello sviluppatore: lingua solo nelle impostazioni), e se il suo modello vocale è installato sul Mac. Una nuova scelta vale per le registrazioni che iniziano dopo.

Comportamento, come lo dice il Model:
- **Checking** (iniziale). All'avvio dell'app: se il modello vocale della lingua scelta è installato → **Ready**; altrimenti → **Downloading** e macOS inizia a scaricarlo.
- **Downloading**. A installazione completata → **Ready**. Se il download fallisce → **Missing**: le impostazioni dicono che la lingua non è ancora disponibile e che il download verrà ritentato. Se l'utente sceglie un'altra lingua: già installata → **Ready**, non installata → **Downloading** (parte il suo download).
- **Missing**. Al ritorno della rete o al riavvio dell'app → **Downloading** (nuovo tentativo). Scelta di un'altra lingua: come sopra.
- **Ready**. Scelta di un'altra lingua: come sopra.
- Ogni volta che il modello della lingua scelta diventa installato si emette `LANGUAGE_READY`, che sblocca le call in attesa della lingua.

Come costruirlo:
- Lingue: "Italiano" = `it-IT`, "English" = `en-US`. Lingua predefinita al primo avvio: italiano. Lingue installate da `SpeechTranscriber.installedLocales`; download con `AssetInventory` (`assetInstallationRequest(supporting:)` per il `SpeechTranscriber` della lingua).
- La finestra delle impostazioni mostra la lingua di trascrizione con il suo stato ("Pronta", "Download in corso…", "Non disponibile, nuovo tentativo appena possibile") e l'interruttore "Avvia all'accesso".
- Avvio all'accesso con `SMAppService.mainApp`, disattivato di base (decisione dello sviluppatore); l'interruttore riflette lo stato reale del servizio.
- Le impostazioni sono salvate in `UserDefaults`.
- Test con Swift Testing delle transizioni (installazione e download sostituibili nei test).
