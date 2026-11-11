---
description: Use when changing the search, ordering, summary display, Markdown export, playback timing or the time and date formats of the main window.
---
# Library rules

## main-window
- The cards of the library are ordered by the start of the call, newest first; an imported call is placed by the time its file was last modified.
- **Filter chips**: "Tutte", then one chip per call app that at least one call of the archive (or of the folder shown) is tied to, in alphabetical order, then "Manuali" when there is a call recorded by hand and "Importate" when there is an imported call. Choosing a chip shows only its calls; the search applies on top of the filter. When the call app of the chosen chip no longer has calls, the filter goes back to "Tutte".
- Folder names are trimmed, at most 60 characters, and unique ignoring case and accents; folders are listed in alphabetical order.
- The line above the title of the library counts the calls whose start falls on today's date in the Mac's calendar; with none it reads "nessuna call oggi" / "no calls today".
- Search: the text typed is trimmed; an empty text matches every call. Otherwise a call matches when one of its fields contains the text, ignoring case, accents and character width.
- Fields searched: the title as shown (the default one when the user gave none), the text of every transcript line, the names the user gave to participants, and the summary as shown (section titles, items and free text, with the participants' current names). The word that stands for an empty list is not searched. The summary is searched whatever the state of the summary and whether summaries are on.
- The initials of a participant on a card and on a chip are the first letter of their name as shown; for "Partecipante <number>" they are the number.
- **Speaking time** of a speaker: the sum of end minus start of its lines; its share is that sum over the sum for every speaker of the call, shown as a whole percentage rounded to the nearest, chips ordered by share, largest first; "Io" gets a chip only when it has lines.
- **Find a word**: the text typed is trimmed and matched in the text of each line as shown, ignoring case, accents and character width; the first found line after the line being heard is shown first; the arrows go round from the last to the first.
- **Waveform** of a call: 44 bars on a card, each the peak level of both tracks over its share of the call, on a scale from −50 dBFS to 0 dBFS with a floor at 4 px; each bar takes the colour of the speaker of the line covering the middle of its time ("Io" when a microphone line, idle colour in silence); worked out once, when the call becomes ready, and again after a separation that runs again.
- Transcript lines are shown and exported ordered by start, then by end.
- The summary as shown has the sections key concepts, decisions, next steps, in this order, then the free text only when it is not empty once trimmed. An empty list shows the empty-list word. A next step with an owner is written `<text> (<owner>)`.
- Section titles are in the interface language: Italian "Concetti chiave", "Decisioni", "Prossimi passi", "Altro", empty-list word "Nessuno"; English "Key concepts", "Decisions", "Next steps", "Other", "None". The items stay in the language the summary was written in.
- Every "Partecipante <number>" (the number not followed by another digit) in the summary is replaced by the name the user gave that participant, when it is not empty, or by "Participant <number>" in the English interface. The stored summary is never changed.
- Markdown export, in the interface language, paragraphs separated by a blank line and the file ending with a newline:
  1. `# <title as shown>`
  2. `<day>, <time> · durata <duration> · lingua <language name>` (English: `<day>, <time> · duration <duration> · language <language name>`)
  3. only when the call has a summary: `## Sintesi` (`## Summary`), then for each section `### <title>` followed by its items as `- <item>` lines, or the empty-list word, or the free text; then `## Trascrizione` (`## Transcript`)
  4. one paragraph per line: `**<speaker>** [<clock of the line start>]: <text>`
- The default export file name is the title as shown with every `/` replaced by `-`; the file is Markdown text in UTF-8.
- Formats, in the locale of the interface language (`it_IT` or `en_US`):
  - clock: `mm:ss`, rounded down, negative times as `00:00`, minutes going past 59;
  - duration: `mm:ss`, or `h:mm:ss` from one hour on; on cards `<n> min`, or `<h> h <m> min` from one hour on;
  - day and time: `27 ottobre 2026, 10:41` / `27 October 2026, 10:41`; on cards `Oggi 10:00` / `Today 10:00` for today, otherwise the short day name and the time (`mar 16:30` / `Tue 16:30`) within the last seven days, otherwise `27 ott 10:41` / `27 Oct 10:41`;
  - language: its name in the interface language, for example `italiano (Italia)` / `Italian (Italy)`, or the identifier when unknown.

## playback
- The time reached and the current line are updated every 100 ms while playing.
- The length of the audio is that of the longest readable track; with no readable track it is the recorded duration of the call and nothing can be played.
- Every time asked (play from a line, moving the position) is kept between 0 and the length of the audio.
- A track shorter than the time asked is not played; when no track is left, playback ends at once.
- Current line: the line with start ≤ time < end; the end of a line belongs to what follows. When lines overlap, the one that started last wins; in silence there is no current line.
- **Skip silence**: while playing and skipping is on, when the time reached is in a stretch without lines longer than 2 seconds (from the end of the line before to the start of the next one, or from the start of the audio, or up to its end), playback jumps to 0.3 seconds before the start of the next line, or ends when there is none.
- **Speed**: 1, 1.25, 1.5, 2 and 0.75 times, in this order; every time measured by playback (time reached, current line, length) stays in the time of the audio, not of the clock.
