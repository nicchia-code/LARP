---
description: Use when building the menu bar icon, its popover, the proposal panel, the recording notices, the recording pill or the live window.
---
# Menu bar and recording

## recorder
- **Menu bar icon**: the coloured LARP mark outside a recording; during a recording a red `#FF5A40` dot followed by the elapsed time in digits of equal width; while paused the dot is `#A3A69B`.
- **Popover**, 340 px wide, ink `#121310` background, radius 18, 14 px padding, dark appearance:
  - header: the LARP mark 30 px and "LARP" in Bricolage Grotesque 20 px bold, and on the right the state in 13 px `#A3A69B` ("Pronto quando vuoi" when idle or after "Non questa", "Call rilevata" when proposing, "In registrazione" or "In pausa" when recording);
  - the card of the state, `#1D1F1A`, radius 14, 16 px padding: idle, the eyebrow "Registrazione manuale", the line "Nessuna call in corso" and a full-width lime button "Registra" with the shortcut on its right; proposing, the proposal card below; recording, the eyebrow with a red dot "In registrazione" (or "In pausa"), the title of the call in Bricolage Grotesque 22 px semibold, the elapsed time in JetBrains Mono, a row with "Pausa" / "Riprendi" as a dark outline button and "Ferma registrazione" as a white button with an ink square, and the link "Apri finestra dal vivo";
  - rows in 13 px, separated by `#2A2C26` dividers: "Audio della call" with the call app of the recording or of the proposal on the right in `#A3A69B` ("—" otherwise); "Microfono" with the choice box of the microphone; "Registra automaticamente le call rilevate" with a switch;
  - a divider `#2A2C26`, then the footer rows in 13 px `#E9EAE3`: "Apri archivio" on the left, "Impostazioni" and "Esci" on the right.
- **Proposal card**, the same wherever it appears (panel, popover, banner of the library): the eyebrow with a red `#FF5A40` dot "In onda ora · <call app>", in JetBrains Mono `#A3A69B`; the title "Call rilevata" in Bricolage Grotesque 22 px semibold white; a full-width lime button 52 px high, radius 12, with an ink dot, "Registra questa call" and the shortcut on its right; under it the text button "Non questa" in 13 px `#E9EAE3`.
- **Proposal panel**: the proposal card alone on ink, radius 18, 320 px wide, under the menu bar icon, with a soft shadow.
- **Notices** under the menu bar icon (echo not removed, system audio not available, microphone lost, system audio lost): ink cards, radius 14, 300 px wide, white 13 px text with an icon in `#FF5A40` for losses and `#D4F24A` for information; a button that opens System Settings is an outline button on dark.
- **Alerts** of a missing permission or of a recording that could not start stay system alerts.

## recording-view
- **Pill**: ink, 64 px high, radius 32, about 390 px wide, 24 px above the bottom edge of the screen, centred, with a soft shadow: a red `#FF5A40` dot (`#A3A69B` while paused), the elapsed time in JetBrains Mono 16 px white, a live waveform of about 20 lime bars, then three round 44 px buttons: "Segnalibro" (bookmark glyph) and "Pausa" / "Riprendi" (pause or play glyph) on `#2A2C26` with white glyphs, "Ferma" white with an ink square. A click on the time or the waveform opens the live window. Buttons have their names as tooltips and accessibility labels.
- **Live window**: about 1040 × 680 px, ink background, dark appearance, window buttons on the dark surface, no title bar.
  - top row: a chip `#2A1512` with a red dot and "REC <elapsed>" in JetBrains Mono `#FF8672` ("IN PAUSA" while paused), the title of the call in 13 px semibold white, then "· <call app> · <language>" in `#A3A69B`; on the right the levels "Call" and "Mic", each a label in 12 px `#A3A69B` and a bar 56 × 4 px, lime on `#3A3C36`;
  - centre column: the final lines, each with the eyebrow "● <SPEAKER> · <time>" in JetBrains Mono `#A3A69B` (the dot of the speaker colour, "· SEGNALIBRO" added for a bookmarked line) over the text in 15 px `#E9EAE3`; the newest lines at the bottom, older ones scrolling up; below them the text being recognised, with the eyebrow "<SPEAKER> · STA PARLANDO" in lime and the text in Bricolage Grotesque 32 px semibold white, its last words in `#8A8D82`;
  - right column, 200 px: the card "Nella call" (`#1D1F1A`, radius 18) with one row per speaker, avatar and name, and a small lime level glyph next to whoever is speaking; under it the card "Le tue note" with the notes, each with its time in JetBrains Mono, and a text field "Scrivi una nota…" that adds the note with Return;
  - bottom row: a wide waveform of the recording (the last minute in lime, older bars `#3A3C36`), then "Segnalibro" with its shortcut as a dark outline button, "Pausa" / "Riprendi" as a dark outline button, and "Ferma" as a lime button with an ink square.
- The live transcript scrolls by itself to the newest line unless the user has scrolled up; it follows again when scrolled back to the bottom.
