---
description: Use when building the menu bar item, the proposal, the archive window, the playback controls or the settings window.
---
# Screens

## General
- All texts of the interface are in Italian.
- Standard macOS look with system controls, following light and dark mode.

## recorder
- The menu bar icon is a microphone outline when idle and a filled red dot while recording, with the elapsed time next to it while recording.
- The menu bar menu shows "Registra" when idle, "Ferma registrazione" while recording, "Apri archivio", "Impostazioni…" and "Esci".

## recorder/Proposing
- The proposal is a small panel under the menu bar icon that does not steal focus, saying "Call rilevata in <app>" with a "Registra" button; it stays until accepted or until the call app stops using the microphone.
- While the proposal is shown, "Registra" in the menu bar menu accepts the proposal.
- A missing permission is shown as an alert that names the permission and has a button opening the right pane of System Settings.

## recorder/Recording
- When the sound of the other participants cannot be removed from the microphone, at the start of a recording or after a change of audio devices, a small panel under the menu bar icon that does not steal focus says "Cancellazione dell'eco non disponibile: usa le cuffie per non sentire gli altri due volte." and disappears by itself after 10 seconds.

## main-window
- Split view: on the left a search field and the list of calls, newest first, each with title, date and duration; on the right the selected call.
- Each call in the list shows its state when it is not Ready: "In registrazione", "In attesa della lingua", "Trascrizione…", "Separazione voci…", "Voci da separare", "Rifinitura testo…", "Testo da rifinire".
- The selected call shows the title (editable in place), date, duration, the app of the call, the playback controls and the transcript; each line shows the speaker, the start time as mm:ss and the text.
- Clicking a speaker name of a participant allows renaming it.
- Toolbar actions: "Esporta…" (disabled when there is no transcript), "Rifinisci testo" (enabled only when transcript refinement is on and the call is Ready or in "Testo da rifinire"), "Ripristina originale" (enabled only when the call has been refined, also with refinement off) and "Elimina", which asks for confirmation before deleting.

## playback
- Playback controls: play/pause button, current time and total time, a progress bar the user can drag.
- While playing, the line being heard is highlighted and kept visible by scrolling.

## settings
- The settings window has the transcription language ("Italiano", "English") with its status ("Pronta", "Download in corso…", "Non disponibile, nuovo tentativo appena possibile"), the "Rifinisci il testo con omp" switch and the "Avvia all'accesso" switch.
- While "Rifinisci il testo con omp" is on, the status of omp is shown next to it: "Verifica in corso…", "omp pronto" or "omp non trovato".
