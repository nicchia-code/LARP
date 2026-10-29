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
- When the sound of the other participants cannot be removed from the microphone, at the start of a recording or after a change of audio devices, and the system audio is being recorded, a small panel under the menu bar icon that does not steal focus says "Cancellazione dell'eco non disponibile: usa le cuffie per non sentire gli altri due volte." and disappears by itself after 10 seconds. It is never shown in a recording without the system audio.
- When a recording started by hand records only the microphone, a small panel under the menu bar icon that does not steal focus says "Audio di sistema non disponibile: si registra solo il microfono." and disappears by itself after 10 seconds; when the system audio permission is missing, the panel has a button "Apri Impostazioni di Sistema" that opens the right pane of System Settings.

## recorder/Microphone lost
- A small panel under the menu bar icon that does not steal focus says "Microfono non disponibile: la registrazione prosegue senza la tua voce."; it stays while the microphone is lost and disappears when the microphone comes back or the recording ends.

## system-audio/Lost
- A small panel under the menu bar icon that does not steal focus says "Audio di sistema non disponibile: la registrazione prosegue senza gli altri partecipanti."; it stays while the system audio is lost and disappears when the system audio comes back or the recording ends.
- When the microphone is lost at the same time, its panel and this one are shown stacked, each appearing and disappearing on its own.

## main-window
- Split view: on the left a search field and the list of calls, newest first, each with title, date and duration; on the right the selected call.
- Each call in the list shows its state when it is not Ready: "In registrazione", "In attesa della lingua", "Trascrizione…", "Separazione voci…", "Voci da separare", "Rifinitura testo…", "Testo da rifinire". A call that is Ready shows "Sintesi…" while its summary is being written and "Sintesi da fare" while the summary waits to be tried again.
- The selected call shows the title (editable in place), date, duration, the app of the call, the playback controls and, below them, a segmented control "Sintesi" / "Trascrizione" that shows one of the two; selecting a call opens it on "Sintesi" when it has a summary, otherwise on "Trascrizione".
- In "Trascrizione" each line shows the speaker, the start time as mm:ss and the text.
- Clicking a speaker name of a participant allows renaming it.
- Toolbar actions: "Esporta…" (disabled when there is no transcript), "Rifinisci testo" (enabled only when transcript refinement is on and the call is Ready or in "Testo da rifinire"), "Ripristina originale" (enabled only when the call has been refined, also with refinement off), "Sintetizza" (enabled only when call summaries are on, the transcript has at least one line, the participants have been told apart and no summary is being written for the call) and "Elimina", which asks for confirmation before deleting.

## call-summary
- "Sintesi" shows the sections in a fixed order, key concepts, decisions, next steps, then the free text, each with its title and its items as a bulleted list; a next step with someone to do it shows the name after the text.
- The summary is read-only; its text can be selected and copied.
- "Sintesi" shows, above the summary or in its place: "Sintesi in corso…" while it is being written, "Sintesi non riuscita, nuovo tentativo appena possibile" while it waits to be tried again, and "Nessuna sintesi" when the call has none and none is being written.

## playback
- Playback controls: play/pause button, current time and total time, a progress bar the user can drag.
- While playing, the line being heard is highlighted and kept visible by scrolling.

## settings
- The settings window has the transcription language ("Italiano", "English") with its status ("Pronta", "Download in corso…", "Non disponibile, nuovo tentativo appena possibile"), the "Rifinisci il testo con omp" switch, the "Sintesi con omp" switch and the "Avvia all'accesso" switch.
- While "Rifinisci il testo con omp" or "Sintesi con omp" is on, the status of omp is shown once, below the two switches: "Verifica in corso…", "omp pronto" or "omp non trovato".
