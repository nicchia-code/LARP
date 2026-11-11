---
description: Use when building the main window, its sidebar, the library of calls, the list of bookmarks, the page of a call or its playback bar.
---
# Main window, library and call page

## main-window
- **Window**: about 1200 × 920 px when first opened, at least 900 × 600; no visible title bar: the window buttons sit on the dark sidebar, the content reaches the top edge, and the window has no toolbar.
- **Sidebar**: 210 px wide, ink, full height, 16 px top and 14 px side padding, 24 px between its groups; the LARP mark 30 px with "LARP"; "Nuova registrazione" as a full-width lime button 40 px high with ink text and the shortcut on its right in JetBrains Mono, disabled (40 % opacity) while something is proposed or recorded; then the items "Tutte le call" and "Segnalibri", 13 px `#E9EAE3`, 8 × 10 px padding, radius 8, the selected one `#23251F` with lime semibold text; "Impostazioni" at the bottom.
- **Library pages**: paper background, 28 × 36 px padding, 24 px between blocks.
  - header: the eyebrow "<day short name> <day> <month short name> · <n> call oggi", the title of the view in Bricolage Grotesque 44 px, and on the right a search field 300 px wide with the placeholder "Cerca parole, persone, decisioni";
  - banner of the proposal, ink, radius 18, 20 × 22 px padding: the eyebrow with the red dot "In onda ora · <call app>", the title "Call rilevata" in Bricolage Grotesque 24 px, and on the right the text button "Non questa" in `#E9EAE3` and the lime button "Registra questa call" with an ink dot;
  - **all calls**: a grid of cards, at least 280 px each and as many columns as fit, 16 px gaps. A card is a white card with 14 px between its rows: eyebrow with day and time on the left and the call app on the right; the title in Bricolage Grotesque 19 px, at most two lines; the summary line or status in 13 px `#5A5D55`, at most two lines, at least two lines high; a row with the avatars of the participants ("Io" included), the duration in 12 px `#5A5D55` and, on the right, the status chip: lime for a call whose transcript is complete, `#ECECE4` with "…" texts while it is being worked on;
  - **bookmarks view**: one white card per call with bookmarks, its eyebrow with day, time and call app and its title in Bricolage Grotesque 19 px, then one row per bookmark: the time in a JetBrains Mono chip `#ECECE4` and the line text in 13 px, at most two lines; a row highlights `#F1F1EA` under the pointer;
  - the empty texts sit centred in the content area in 13 px `#5A5D55`.
- **Call page**: paper background; 28 × 32 px padding.
  - top row: "‹ Archivio" as a 13 px link on the left; on the right the outline button "Esporta" and an outline button "…" opening the menu of the call;
  - the eyebrow "<call app> · <day and time> · <duration>", then the title in Bricolage Grotesque 56 px (editable in place, same font), then the status of the call in 13 px `#5A5D55`, then the row of participant chips (avatar and name, 32 px high, radius 16, white with a `#E4E4DC` border), where clicking a name renames that participant;
  - two columns, about 55 % and 45 %, 24 px apart. Left: the tabs "Sintesi", "Le mie note", "Segnalibri" in Bricolage Grotesque 18 px, the selected one ink with a 3 px lime underline and the others `#5A5D55`, over a 1 px ink line; "Sintetizza" or "Rigenera" as an outline button on the right of the tabs while the summary is shown.
    - Summary: the sections of the summary each with a JMono eyebrow title and its items in 15 px separated by `#E4E4DC` dividers, decisions numbered "01", "02" in Bricolage Grotesque 20 px; without a summary the state of the summary in 15 px `#5A5D55`.
    - Notes: one row per note, its time in a JetBrains Mono chip `#ECECE4` (none without time), its text in 15 px editable in place, a delete button that appears under the pointer; at the bottom a white field "Scrivi una nota…" that adds the note with Return.
    - Bookmarks: one row per bookmark, its time in a JetBrains Mono chip, the line text in 15 px, a delete button under the pointer.
  - Right: the transcript panel, a white card with the heading "Trascrizione" in Bricolage Grotesque 20 px; each line is the dot of its speaker colour and the eyebrow "<SPEAKER> <time>" over the text in 13 px, with "⌑ SEGNALIBRO" in JetBrains Mono at the right of the eyebrow of a bookmarked line; the line being heard has a `#EEF8B4` background, radius 10;
  - below the columns, the playback bar across the page.

## playback
- **Playback bar**: ink, radius 18, 64 px high, 14 px padding: a 48 px round lime play/pause button with an ink glyph, the time reached in JetBrains Mono white, the timeline, the length of the audio in JetBrains Mono `#A3A69B`, and a round 36 px "Segnalibro" button on `#2A2C26` that marks the time reached.
- **Timeline**: one segment per transcript line placed at its time, coloured with its speaker colour, radius 4, 2 px gaps; the parts already heard are full colour and the rest at 45 % opacity; a 2 px white bar marks the time reached; small lime ticks above the timeline mark the bookmarks; clicking or dragging on the timeline moves the position.
- Without audio the bar shows "Audio non disponibile" in `#A3A69B` in place of the timeline, with the play and bookmark buttons disabled.
