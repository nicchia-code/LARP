# Onboarding

The welcome window shown once, at the first launch of a version of LARP that has it: it asks for the permissions and the first choices before the first call. Once ended it never comes back; everything it holds stays in the settings.

## States

### Not done (initial)
The welcome window was never ended on this Mac.
- `macos.APP_LAUNCHED` → Permissions step: the app comes to the front and the welcome window opens.

### Permissions step
"Passo 1 di 2 · Permessi": a row for the microphone ("La tua voce nella conversazione") and one for the system audio ("Tutti gli altri, da Teams, Zoom, Meet e ogni altra app"), each with "Consenti", or "Consentito" once granted; the line "Tutto si può cambiare più tardi nelle Impostazioni."; "Continua".
- `user.ALLOW_MICROPHONE` → Permissions step: the microphone permission is asked to the user when not decided yet; when it was refused before, System Settings opens on its pane.
- `user.ALLOW_SYSTEM_AUDIO` → Permissions step: the system audio permission is asked by creating and destroying a system audio tap, which makes macOS ask the first time; when it was refused before, System Settings opens on its pane.
- `user.CONTINUE_SETUP` → Choices step: also when a permission is missing.
- `user.FINISH_SETUP` → Done: by closing the window.

### Choices step
"Passo 2 di 2 · Scelte": the transcription language with the state of its speech model, and the switches "Rifinisci il testo con omp" and "Sintetizza quando la call finisce" with the state of omp while one is on, as in the settings; "Inizia".
- `user.FINISH_SETUP` → Done

### Done (final)
The welcome window is closed and is never shown again; that it was ended is kept across launches.
