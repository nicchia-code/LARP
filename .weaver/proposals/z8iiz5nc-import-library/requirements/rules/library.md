---
description: Use when changing the search, ordering, summary display, Markdown export, playback timing or the time and date formats of the archive window.
---
# Library rules

## main-window
- The list is ordered by the start of the call, newest first.
- Search: the text typed is trimmed; an empty text matches every call. Otherwise a call matches when one of its fields contains the text, ignoring case, accents and character width.
- Fields searched: the title as shown (the default one when the user gave none), the text of every transcript line, the names the user gave to participants, and the summary as shown (section titles, items and free text, with the participants' current names). The word that stands for an empty list is not searched. The summary is searched whatever the state of the summary and whether summaries are on.
- Transcript lines are shown and exported ordered by start, then by end.
- The summary as shown has the sections key concepts, decisions, next steps, in this order, then the free text ("Altro" / "Other") only when it is not empty once trimmed. An empty list shows "Nessuno" / "None". A next step with an owner is written `<text> (<owner>)`.
- Section titles are English ("Key concepts", "Decisions", "Next steps", "Other", "None") when the language of the summary is English, otherwise Italian ("Concetti chiave", "Decisioni", "Prossimi passi", "Altro", "Nessuno").
- Every "Partecipante <number>" (the number not followed by another digit) in the summary is replaced by the name the user gave that participant, when it is not empty. The stored summary is never changed.
- Markdown export, paragraphs separated by a blank line and the file ending with a newline:
  1. `# <title as shown>`
  2. `<day>, <time> · durata <duration> · lingua <language name>`
  3. only when the call has a summary: `## Sintesi`, then for each section `### <title>` followed by its items as `- <item>` lines, or the empty-list word, or the free text; then `## Trascrizione`
  4. one paragraph per line: `**<speaker>** [<clock of the line start>]: <text>`
- The default export file name is the title as shown with every `/` replaced by `-`; the file is Markdown text in UTF-8.
- Formats, in Italian (`it_IT`):
  - clock: `mm:ss`, rounded down, negative times as `00:00`, minutes going past 59;
  - duration: `mm:ss`, or `h:mm:ss` from one hour on;
  - day and time: `27 ottobre 2026, 10:41`;
  - language: its Italian name, for example `italiano (Italia)`, or the identifier when unknown.

## playback
- The time reached and the current line are updated every 100 ms while playing.
- The length of the audio is that of the longest readable track; with no readable track it is the recorded duration of the call and nothing can be played.
- Every time asked (play from a line, moving the position) is kept between 0 and the length of the audio.
- A track shorter than the time asked is not played; when no track is left, playback ends at once.
- Current line: the line with start ≤ time < end; the end of a line belongs to what follows. When lines overlap, the one that started last wins; in silence there is no current line.
